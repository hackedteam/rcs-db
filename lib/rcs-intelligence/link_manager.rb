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
    ident = Entity.where({:_id.ne => entity._id, "handles.type" => handle.type, "handles.handle" => handle.handle, :path => entity.path.first}).first
    return unless ident

    # if found we consider them identical
    trace :info, "Identity match: '#{entity.name}' and '#{ident.name}' -> #{handle.handle}"

    # create the link
    entity.add_link({entity: ident, type: :identity, info: handle.handle, versus: :both})
  end

  def link_handle(entity, handle)
    return unless $license['intelligence']


    # search for a peer in all the entities of this operation
    ::Entity.where(path: entity.path.first).each do |e|

      trace :debug, "Checking '#{e.name}' for peer links: #{handle.handle} (#{handle.type})"

      # if we find a peer, create a link
      e.peer_versus(handle.handle, handle.type).each do |versus|
        entity.add_link({entity: e, type: :peer, info: handle.type, versus: versus})
      end
    end
  end

end

end
end

