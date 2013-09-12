#
#  Module for handling peer aggregations
#

require_relative 'frequencer'

module RCS
module Aggregator

class PeerAggregator
  extend RCS::Tracer

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
    bidirectional = hash[:type] == :skype

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
    if bidirectional
      ev.data['rcpt'].split(',').each do |rcpt|
        data << hash.merge(peer: rcpt.strip.downcase, sender: ev.data['from'].strip.downcase, versus: :in)
        data << hash.merge(peer: ev.data['from'].strip.downcase, sender: rcpt.strip.downcase, versus: :out)
      end
    elsif versus == :in
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

  def self.create_suggested_peer(target_id, params)
    time = Time.parse(params[:day])
    peer = params[:data][:peer]
    type = params[:type]
    versus = params[:data][:versus]

    # a call is always bidirectional, we don't care here who initiated it
    versus = :both if params[:ev_type].eql? 'call'

    frequencer_agg = Aggregate.target(target_id).find_or_create_by(type: :frequencer, day: '0', aid: '0')

    # load the frequencer from the db, if already saved, otherwise create a new one
    if frequencer_agg.data['frequencer']
      begin
        trace :debug, "Reloading frequencer from saved status "
        frequencer = Frequencer.new_from_dump(frequencer_agg.data['frequencer'])
      rescue Exception => e
        trace :warn, "Cannot restore frequencer status, creating a new one..."
        frequencer = Frequencer.new
      end
    else
      trace :debug, "Creating a new frequencer for target #{target_id}"
      frequencer = Frequencer.new
    end

    frequencer.feed(time, "#{type} #{peer}", versus) do |output|
      type, peer = output.split(' ')

      entity = Entity.targets.any_in(path: [Moped::BSON::ObjectId.from_string(target_id)]).first

      # search for existing entity or create a new one
      if (old_entity = Entity.same_path_of(entity).with_handle(type, peer).first)
        if old_entity.level.eql? :ghost
          old_entity.level = :suggested
          old_entity.save
          RCS::DB::LinkManager.instance.add_link from: entity, to: old_entity, level: :automatic, type: :peer, versus: :both
        end
      else
        description = "Created automatically because #{entity.name} has frequent communication with #{type} #{peer}"
        new_entity = Entity.create!(name: peer, type: :person, level: :suggested, path: [entity.path.first], desc: description)
        new_entity.create_or_update_handle(type, peer)
      end
    end

    # save the frequencer status into the aggregate
    frequencer_agg.data = {frequencer: frequencer.dump}
    frequencer_agg.save
  end

end

end
end