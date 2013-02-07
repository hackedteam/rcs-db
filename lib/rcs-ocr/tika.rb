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

      text = RCS::DB::CrossPlatform.exec_with_output "java", "-jar ocr/tika/tika.jar -t #{input_file}"
      meta = RCS::DB::CrossPlatform.exec_with_output "java", "-jar ocr/tika/tika.jar -m #{input_file}"

      return false if text.nil? or meta.nil? or text.size + meta.size == 0

      out = text +
            "\n====== END OF FILE ======\n\n" +
            meta

      #trace :debug, "File metadata: #{meta.inspect}"

      File.open(output_file, 'wb') {|f| f.write out}

      return true
    end

  end

end

end #DB::
end #RCS::
