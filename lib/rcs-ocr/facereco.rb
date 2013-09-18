#
#  OpenCV (www.opencv.org)
#

# from RCS::Common
require 'rcs-common/trace'

require 'opencv'
include OpenCV

module RCS
module OCR

class FaceRecognition
  extend RCS::Tracer

  class << self

    def have_face_recognition_capabilities?
      File.exist?('ocr/face/haarcascades')
    end

    def detect(input_file)
      return {} unless have_face_recognition_capabilities?

      image = CvMat.load(input_file)
      found = false

      Dir['ocr/face/haarcascades/*'].each do |xml|
        CvHaarClassifierCascade::load(xml).detect_objects(image).each do |region|
          found = true
          trace :debug, "Face detected in #{input_file} by #{File.basename(xml)} [#{region.top_left}, #{region.bottom_right}]"
        end
      end

      trace :info, "Face detected in #{input_file}" if found

      {face: found}
    end

  end

end

end #DB::
end #RCS::
