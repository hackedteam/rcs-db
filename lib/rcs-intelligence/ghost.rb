#
#  Module for handling ghost entities
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class Ghost
  include Tracer
  extend Tracer

  class << self

    def create_and_link_entity(entity, handle)
      return unless handle.is_a? Array

      name, type, handle = *handle

      # search for entity
      ghost = Entity.where({:_id.ne => entity._id, "handles.type" => type, "handles.handle" => handle, :path => entity.path.first}).first

      # create a new entity if not found
      unless ghost
        trace :debug, "Creating ghost entity: #{name} -- #{type} #{handle}"

        ghost = Entity.create!(name: name, type: :person, level: :ghost, path: [entity.path.first])

        # add the handle
        ghost.handles.create!(level: :automatic, type: type, handle: handle)
      end

      # link the two entities
      # the level will be reset to :automatic (if it's the case) by the LinkManager
      RCS::DB::LinkManager.instance.add_link(from: entity, to: ghost, level: :ghost, type: :know, info: handle)
    end

  end

end

end
end

