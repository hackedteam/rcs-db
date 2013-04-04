#
#  Module for handling links between entities
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class LinkManager
  include Singleton
  include Tracer

  def check_identity(entity, handle)
    return unless $license['intelligence']

    trace :debug, "Checking for identity: #{handle.type} #{handle.handle}"

    # search for other entities with the same handle
    ident = Entity.where({:_id.ne => entity._id, "handles.type" => handle.type, "handles.handle" => handle.handle, :path.in => [entity.path.first]}).first
    return unless ident

    trace :info, "Identity match: '#{entity.name}' and '#{ident.name}' -> #{handle.handle}"

    # create the link
    entity.add_link({entity: ident, type: :identity, info: handle.handle, versus: :both})
  end

end

end
end

