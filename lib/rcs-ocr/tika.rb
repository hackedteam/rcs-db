#
#  Apache Tika interface  (http://tika.apache.org/)
#

# from RCS::Common
require 'rcs-common/trace'


module RCS
module OCR

class Tika
  extend RCS::Tracer

  class << self

    def transform(input_file, output_file)

      # under windows the text mode (-t) is broken for arabic chars
      # se we inoke it in html mode and strip the entities
      text = RCS::DB::CrossPlatform.exec_with_output "java", "-jar ocr/tika/tika.jar #{input_file}"
      #meta = RCS::DB::CrossPlatform.exec_with_output "java", "-jar ocr/tika/tika.jar -m #{input_file}"

      return false if text.nil? or text.size == 0

      # strip the html entities
      text_plain = text.strip_html_tags

      # write the output
      File.open(output_file, 'wb') {|f| f.write text_plain}

      return true
    end

  end

end

end #DB::
end #RCS::
