#
#  OpenCV (www.opencv.org)
#

# from RCS::Common
require 'rcs-common/trace'

if RbConfig::CONFIG['host_os'] =~ /mingw/
  require 'ffi'
else
  require 'opencv'
  include OpenCV
end

module RCS
module OCR

module FACE
  extend FFI::Library

  if RbConfig::CONFIG['host_os'] =~ /mingw/
    ffi_lib File.join(Dir.pwd, 'ocr/face/Face.dll')

    ffi_convention :stdcall

    attach_function :detect_faces, [:pointer, :pointer, :int], :int
  end
end

class FaceRecognition
  extend RCS::Tracer

  class << self

    def have_face_recognition_capabilities?
      File.exist?('ocr/face/haarcascades')
    end

    def detect(input_file)
      return {} unless have_face_recognition_capabilities?

      if RbConfig::CONFIG['host_os'] =~ /mingw/
        found = ffi_detect(input_file)
      else
        found = opencv_detect(input_file)
      end

      trace :info, "Face detected in #{input_file}" if found

      {face: found}
    end

    def ffi_detect(input_file)
      face = FACE.detect_faces(input_file, "ocr/face/haarcascades/haarcascade_frontalface_default.xml", 0)
      return (face > 0)
    end

    def opencv_detect(input_file)
      image = CvMat.load(input_file)
      found = false

      Dir['ocr/face/haarcascades/*'].each do |xml|
        CvHaarClassifierCascade::load(xml).detect_objects(image).each do |region|
          found = true
          trace :debug, "Face detected in #{input_file} by #{File.basename(xml)} [#{region.top_left}, #{region.bottom_right}]"
        end
      end
      return found
    end

  end

end

end #DB::
end #RCS::
