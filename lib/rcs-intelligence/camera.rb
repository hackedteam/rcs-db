#
#  Module for handling camera evidence
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class Camera
  include Tracer
  extend Tracer

  class << self

    def save_first_camera(entity, evidence)
      return unless entity.photos.empty?

      file = RCS::DB::GridFS.get(evidence.data['_grid'], entity.path.last.to_s)
      entity.add_photo(file.read)

      trace :info, "Saving first camera picture for #{entity.name}"
    end

  end

end

end
end

