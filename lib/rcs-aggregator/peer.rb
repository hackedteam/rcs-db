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

    hash = {:type => ev.data['program'].downcase, :size => ev.data['content'].length}

    # TODO: remove old chat format (after 9.0.0)
    if ev.data['peer']

      # multiple rcpts creates multiple entries
      ev.data['peer'].split(',').each do |peer|
        data << hash.merge(:peer => peer.strip.downcase, :versus => :both)
      end

      return data
    end

    # new chat format
    if ev.data['incoming'] == 1
      # special case when the agent is not able to get the account but only display_name
      return [] if ev.data['from'].blank?
      data << hash.merge(:peer => ev.data['from'].strip.downcase, :versus => :in)
    elsif ev.data['incoming'] == 0
      # special case when the agent is not able to get the account but only display_name
      return [] if ev.data['rcpt'].blank?
      # multiple rcpts creates multiple entries
      ev.data['rcpt'].split(',').each do |rcpt|
        data << hash.merge(:peer => rcpt.strip.downcase, :versus => :out, sender: ev.data['from'].strip.downcase)
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

  # Extract email from strings like "Ask Me" <ask@me.it>
  # The first part is the nickname, the real email is enclosed by angular brackets
  def self.email_address string
    string.strip.scan(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i).first.downcase
  end

  def self.extract_email ev
    data = []
    # don't aggregate draft mails
    return [] if ev.data['draft']

    hash = {:type => :mail, :size => ev.data['body'].length}

    from = email_address ev.data['from']

    if ev.data['incoming'] == 1
      # there is no :sender in this case
      data << hash.merge(:peer => from, :versus => :in)
    elsif ev.data['incoming'] == 0
      ev.data['rcpt'].split(',').each do |rcpt|
        data << hash.merge(peer: email_address(rcpt), versus: :out, sender: from)
      end
    end

    data
  end

  def self.extract_sms_or_mms ev
    data = []
    hash = {type: ev.data['type'].downcase, size: ev.data['content'].length}

    if ev.data['incoming'] == 1
      unless ev.data['rcpt'].blank? or ev.data['rcpt'].include?(',')
        hash.merge!(sender: ev.data['rcpt'].strip.downcase)
      end
      data << hash.merge(peer: ev.data['from'].strip.downcase, versus: :in)
    elsif ev.data['incoming'] == 0
      ev.data['rcpt'].split(',').each do |rcpt|
        data << hash.merge(peer: rcpt.strip.downcase, versus: :out, sender: ev.data['from'].strip.downcase)
      end
    end

    data
  end

  def self.extract_message ev
    if ev.data['type'] == :mail
      extract_email ev
    else
      extract_sms_or_mms ev
    end
  end
end

end
end