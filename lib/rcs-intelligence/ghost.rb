require 'rcs-common/trace'

module RCS
module Intelligence

module Ghost
  extend Tracer
  extend self

  def create_and_link_entity(entity, handle_attrs)
    return if handle_attrs.blank?

    name, type, handle = handle_attrs[:name], handle_attrs[:type], handle_attrs[:handle]

    # search for entity
    ghost = Entity.same_path_of(entity).where("handles.type" => type, "handles.handle" => handle).first

    # create a new entity if not found
    unless ghost
      trace :debug, "Creating ghost entity: #{name} -- #{type} #{handle}"

      ghost = Entity.create!(name: name, type: :person, level: :ghost, path: [entity.path.first])
      # add the handle
      ghost.create_or_update_handle(type, handle, name)
    end

    # link the two entities
    # the level will be reset to :automatic (if it's the case) by the LinkManager
    RCS::DB::LinkManager.instance.add_link(from: entity, to: ghost, level: :ghost, type: :know, versus: :out, info: handle)
  end
end

end
end
