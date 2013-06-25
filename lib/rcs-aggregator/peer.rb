#
#  Module for handling peer aggregations
#

module RCS
module Aggregator

class PeerAggregator

  # Search for all the @-prefixed word in the twit content
  def self.twit_recipients twit_content
    return [] if twit_content.blank?

    regexp = /(^|\s)(@[a-zA-Z0-9\_]+)(\s|$)/
    ary = twit_content.scan(regexp).flatten
    ary.reject!(&:blank?)
    ary.map! { |username| username.gsub('@', '') }
  end

  def self.extract_chat(ev)
    data = []

    # "peer" attribute was present before 9.0.0
    # than has been replaced by "from" and "rcpt"
    peer = "#{ev.data['peer']}".strip.downcase
    from = "#{ev.data['from']}".strip.downcase
    rcpt = "#{ev.data['rcpt']}".strip.downcase

    hash = {:time => ev.da, :type => ev.data['program'].downcase.to_sym, :size => ev.data['content'].length}

    # When the program is twitter, extracts peers from the
    # twit content.
    if hash[:type] == :twitter
      rcpts = twit_recipients(ev.data['content'])
      from.gsub!('@', '')

      rcpts.each do |rcpt|
        attributes = {peer: rcpt, versus: :out}
        attributes.merge!(sender: from) unless from.blank? # < 9.0.0
        data << hash.merge(attributes)
      end

      return data
    end

    # TODO: remove old chat format (after 9.0.0)
    unless peer.blank?
      # multiple rcpts creates multiple entries
      peer.split(',').each do |peer|
        data << hash.merge(:peer => peer.strip, :versus => :both)
      end

      return data
    end

    # new chat format >= 9.0.0
    if ev.data['incoming'] == 1
      # special case when the agent is not able to get the account but only display_name
      return [] if from.blank?
      hash.merge!(:peer => from, :versus => :in)
      hash.merge!(:sender => rcpt) unless rcpt.blank? or rcpt =~ /\,/
      data << hash
    elsif ev.data['incoming'] == 0
      # special case when the agent is not able to get the account but only display_name
      return [] if rcpt.blank?
      # multiple rcpts creates multiple entries
      rcpt.split(',').each do |rcpt|
        data << hash.merge(:peer => rcpt.strip, :versus => :out, sender: from)
      end
    end

    return data
  end

  def self.extract_call(ev)
    data = []
    versus = ev.data['incoming'] == 1 ? :in : :out
    hash = {:time => ev.da, :versus => versus, :type => ev.data['program'].downcase.to_sym, :size => ev.data['duration'].to_i}

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

    hash = {:time => ev.da, :type => :mail, :size => ev.data['body'].length}

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
    hash = {:time => ev.da, type: ev.data['type'].downcase.to_sym, size: ev.data['content'].length}

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