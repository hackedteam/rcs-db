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

    trace :debug, "checking for identity: #{entity.inspect}, #{handle.inspect}"
  end

end

end
end

