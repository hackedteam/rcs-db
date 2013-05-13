#
#  Module for handling peer aggregations
#

module RCS
module Aggregator

class PeerAggregator

  def self.extract_chat(ev)
    data = []

    # twitter does not have a peer to sent message to :)
    # skip if for aggregation
    return [] if ev.data['program'].downcase.eql? 'twitter'

    # TODO: remove old chat format (after 9.0.0)
    if ev.data['peer']
      # multiple rcpts creates multiple entries
      ev.data['peer'].split(',').each do |peer|
        data << {:peer => peer.strip.downcase, :versus => :both, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
      end

      return data
    end

    # new chat format
    if ev.data['incoming'] == 1
      # special case when the agent is not able to get the account but only display_name
      return [] if ev.data['from'].eql? ''
      data << {:peer => ev.data['from'].strip.downcase, :versus => :in, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
    elsif ev.data['incoming'] == 0
      # special case when the agent is not able to get the account but only display_name
      return [] if ev.data['rcpt'].eql? ''
      # multiple rcpts creates multiple entries
      ev.data['rcpt'].split(',').each do |rcpt|
        data << {:peer => rcpt.strip.downcase, :versus => :out, :type => ev.data['program'].downcase, :size => ev.data['content'].length}
      end
    end

    return data
  end

  def self.extract_call(ev)
    data = []
    versus = ev.data['incoming'] == 1 ? :in : :out
    hash = {:versus => versus, :type => ev.data['program'].downcase, :size => ev.data['duration'].to_i}

    # TODO: remove old call format (after 9.0.0)
    if ev.data['peer']
      # multiple peers creates multiple entries
      ev.data['peer'].split(',').each do |peer|
        hash.merge!(sender: ev.data['caller'].strip.downcase) if ev.data['caller']
        data << hash.merge(peer: peer.strip.downcase)
      end

      return data
    end

    # new call format
    if versus == :in
      data << hash.merge(peer: ev.data['from'].strip.downcase, sender: ev.data['rcpt'].strip.downcase)
    else
      # multiple rcpts creates multiple entries
      ev.data['rcpt'].split(',').each do |rcpt|
        data << hash.merge(peer: rcpt.strip.downcase, sender: ev.data['from'].strip.downcase)
      end
    end

    return data
  end

  def self.extract_message(ev)
    data = []

    # MAIL message
    if ev.data['type'] == :mail

      # don't aggregate draft mails
      return [] if ev.data['draft']

      if ev.data['incoming'] == 1
        #extract email from string "Ask Me" <ask@me.it>
        from = ev.data['from'].scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
        data << {:peer => from.downcase, :versus => :in, :type => :mail, :size => ev.data['body'].length}
      elsif ev.data['incoming'] == 0
        ev.data['rcpt'].split(',').each do |rcpt|
          #extract email from string "Ask Me" <ask@me.it>
          to = rcpt.strip.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first
          data << {:peer => to.downcase, :versus => :out, :type => :mail, :size => ev.data['body'].length}
        end
      end
    # SMS and MMS
    else
      if ev.data['incoming'] == 1
        data << {:peer => ev.data['from'].strip.downcase, :versus => :in, :type => ev.data['type'].downcase, :size => ev.data['content'].length}
      elsif ev.data['incoming'] == 0
        ev.data['rcpt'].split(',').each do |rcpt|
          data << {:peer => rcpt.strip.downcase, :versus => :out, :type => ev.data['type'].downcase, :size => ev.data['content'].length}
        end
      end
    end

    return data
  end

end

end
end