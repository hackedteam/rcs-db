#
#  OpenCV (www.opencv.org)
#

# from RCS::Common
require 'rcs-common/trace'

require 'ffi'

unless RbConfig::CONFIG['host_os'] =~ /mingw/
  require 'opencv'
  include OpenCV
end

module RCS
module OCR

=begin
  typedef int (*DetectFace_t)(char *, char *, int);

	HMODULE hmod = LoadLibrary(L"Face.dll");
	DetectFace_t detect_faces = (DetectFace_t)GetProcAddress(hmod, "detect_faces");

	faces = detect_faces(input, "haarcascade_frontalface_default.xml", 1);

=end

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
      trace :error, "Cannot load xml haar file" if face == -1
      trace :error, "Cannot load image file" if face == -2
      return (face > 0)
    end

    def opencv_detect(input_file)
      image = CvMat.load(input_file)
      found = []

      Dir['ocr/face/haarcascades/*'].each_with_index do |xml, index|
        found[index] = false
        CvHaarClassifierCascade::load(xml).detect_objects(image, {scale_factor: 1.1, min_neighbor: 3}).each do |region|
          trace :debug, "Face detected in #{input_file} by #{File.basename(xml)} [#{region.top_left}, #{region.bottom_right}]"
          found[index] = true
        end
      end

      # return the element with most occurrences
      return found.group_by { |n| n }.values.max_by(&:size).first
    rescue Exception =>e
      trace :error, "Cannot process image: #{e.message}"
      return false
    end

  end

end

end #DB::
end #RCS::
