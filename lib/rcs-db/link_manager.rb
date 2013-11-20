#
#  Module for handling links between entities
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class LinkManager
  include Singleton
  include Tracer

  def add_link(params)

    first_entity = params[:from]
    second_entity = params[:to]

    raise "Cannot create link on itself (#{first_entity.name})" unless first_entity != second_entity

    if params[:versus]
      versus = params[:versus].to_sym
      opposite_versus = versus if versus.eql? :both
      opposite_versus ||= (versus.eql? :in) ? :out : :in
    end

    # default is automatic
    params[:level] ||= :automatic

    trace :info, "Creating link between #{first_entity.name.inspect} and #{second_entity.name.inspect} [#{params[:level]}, #{params[:type]}, #{versus}]"

    # create a link in this entity
    first_link = first_entity.links.find_or_initialize_by(le: second_entity._id)
    first_link.first_seen = Time.now.getutc.to_i unless first_link.first_seen
    first_link.last_seen = Time.now.getutc.to_i
    first_link.set_level(params[:level])
    first_link.set_type(params[:type])
    first_link.set_versus(versus) if versus
    first_link.add_info params[:info] if params[:info]
    first_link.rel = params[:rel] if params[:rel]

    # and also create the reverse in the other entity
    second_link = second_entity.links.find_or_initialize_by(le: first_entity._id)
    second_link.first_seen = Time.now.getutc.to_i unless second_link.first_seen
    second_link.last_seen = Time.now.getutc.to_i
    second_link.set_level(params[:level])
    second_link.set_type(params[:type])
    second_link.set_versus(opposite_versus) if opposite_versus
    second_link.add_info params[:info] if params[:info]
    second_link.rel = params[:rel] if params[:rel]

    new_links = first_link.new_record? && second_link.new_record?

    first_link.save
    second_link.save

    if new_links
      # check if :ghosts have to be promoted to :automatic
      first_entity.promote_ghost
      second_entity.promote_ghost

      alert_new_link [first_entity, second_entity]
    end

    [[first_entity, first_link], [second_entity, second_link]].each do |entity, link|
      # Do not send any notify if the link hasn't changed
      next if link.previous_changes.empty?

      # notify the links
      entity.push_modify_entity
    end

    if first_link.cross_operation?
      Entity.create_or_update_operation_group(first_entity.path[0], second_entity.path[0])
    end
    # TODO: update any groups even where a link is destroyed

    return first_link
  end

  def alert_new_link(entities)
    return if entities.first.level == :ghost
    return if entities.last.level == :ghost

    RCS::DB::Alerting.new_link(entities)
  end

  def edit_link(params)

    first_entity = params[:from]
    second_entity = params[:to]

    if params[:versus]
      versus = params[:versus].to_sym
      opposite_versus = versus if versus.eql? :both
      opposite_versus ||= (versus.eql? :in) ? :out : :in
    end

    first_link = first_entity.links.connected_to(second_entity).first
    first_link.set_level(params[:level]) if params[:level]
    first_link.type = params[:type] if params[:type]
    first_link.versus = versus if versus
    first_link.add_info params[:info] if params[:info]
    first_link.rel = params[:rel] if params[:rel]
    first_link.save

    second_link = second_entity.links.connected_to(first_entity).first
    second_link.set_level(params[:level]) if params[:level]
    second_link.type = params[:type] if params[:type]
    second_link.versus = opposite_versus if opposite_versus
    second_link.add_info params[:info] if params[:info]
    second_link.rel = params[:rel] if params[:rel]
    second_link.save

    # notify the links
    first_entity.push_modify_entity
    second_entity.push_modify_entity

    return first_link
  end

  def del_link(params)
    first_entity = params[:from]
    second_entity = params[:to]

    trace :info, "Deleting links between '#{first_entity.name}' and '#{second_entity.name}'"

    destroyed = first_entity.links.connected_to(second_entity).destroy_all
    destroyed += second_entity.links.connected_to(first_entity).destroy_all

    # notify the links
    if destroyed > 0
      first_entity.push_modify_entity
      second_entity.push_modify_entity
    end

    nil
  end

  def del_all_links(entity)
    trace :info, "Deleting all links attached to '#{entity.name}'"

    connected_entities = entity
      .links
      .map { |link| link.linked_entity }
      .compact
      .uniq

    connected_entities.each do |connected_entity|
      if connected_entity.links.connected_to(entity).destroy_all > 0
        connected_entity.push_modify_entity
      end
    end

    if entity.links.destroy_all > 0
      entity.push_modify_entity
    end

    nil
  end

  def move_links(params)
    first_entity = params[:from]
    second_entity = params[:to]

    trace :info, "Moving links from '#{first_entity.name}' to '#{second_entity.name}'"

    # delete the links between the 2 entities
    del_link params

    # merge links
    first_entity.links.each do |link|
      linked_entity = link.linked_entity
      backlink = linked_entity.links.connected_to(first_entity).first

      # exclude links between the 2 entities that have to be merged
      next if linked_entity == second_entity

      # Finds (if any) a link from the second entity to the `linked_entity`
      existing_link = second_entity.links.connected_to(linked_entity).first

      if existing_link
        existing_backlink = linked_entity.links.connected_to(second_entity).first

        existing_link.add_info(link.info)
        existing_backlink.add_info(link.info)
      else
        # adds the link to second entity
        second_entity.links << link
        # updates the backlink
        backlink.le = second_entity._id
        backlink.save
      end
    end

    # delete all the old links
    first_entity.links.destroy_all
  end

  # Check if two entities are the same and create a link between them.
  # Search for other entities with the same handle, if found we consider them identical.
  def check_identity(entity, handle)
    Entity.with_handle(handle.type, handle.handle, exclude: entity).each do |other_entity|
      trace :info, "Identity match: #{entity.name.inspect} and #{other_entity.name.inspect} -> #{handle.handle.inspect}"

      # Create the (identity) link
      add_link(from: entity, to: other_entity, type: :identity, info: handle.handle, versus: :both)
    end
  end

  # Creates a link from ENTITY to any onthe entity that have communicated with HANDLE (based on aggregates)
  def link_handle(entity, handle)
    HandleBook.entities_that_communicate_with(handle.type, handle.handle, exclude: entity).each do |peer_entity|
      trace :debug, "Entity #{entity.name.inspect} must be linked to #{peer_entity.name.inspect} via #{handle.handle.inspect} (#{handle.type.inspect})"

      versus = Aggregate.target(peer_entity.target_id).versus_of_communications_with(handle)

      if versus
        add_link(from: peer_entity, to: entity, type: :peer, level: :automatic, info: handle.handle, versus: versus)
      else
        trace :warn, "Cannot tell the communication versus"
      end
    end
  end
end

end
end
