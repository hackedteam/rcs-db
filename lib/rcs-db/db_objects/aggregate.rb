require 'mongoid'
require 'set'
require 'rcs-common/trace'

require_relative '../position/proximity'
require_relative '../target_scoped'

class Aggregate
  include Mongoid::Document
  include RCS::TargetScoped
  include RCS::Tracer
  include RCS::DB::Proximity
  extend RCS::Tracer

  field :aid, type: String                      # agent BSON_ID
  field :day, type: String                      # day of aggregation
  field :type, type: Symbol
  field :count, type: Integer, default: 0
  field :size, type: Integer, default: 0        # seconds for calls, bytes for the others
  field :info, type: Array, default: []         # for summary or timeframe (position)
  field :data, type: Hash, default: {}

  index({aid: 1}, {background: true})
  index({type: 1}, {background: true})
  index({day: 1}, {background: true})
  index({"data.peer" => 1}, {background: true})
  index({"data.type" => 1}, {background: true})
  index({"data.host" => 1}, {background: true})
  index({type: 1, "data.peer" => 1 }, {background: true})
  index({'data.position' => "2dsphere"}, {background: true})

  shard_key :type, :day, :aid

  scope :positions, where(type: :position)

  # The "day" attribute must be a string in the format of YYYYMMDD
  # or the string "0" (when the type if :postioner or :summary)
  validates_format_of :day, :with => /\A(\d{8}|0)\z/
  # Valalidates the presence of the shard key attributes
  validates_presence_of :type, :day, :aid

  def to_point
    raise "not a position" unless type.eql? :position
    time_params = (info.last.symbolize_keys rescue nil) || {}
    Point.new time_params.merge(lat: data['position'][1], lon: data['position'][0], r: data['radius'])
  end

  def position
    {latitude: self.data['position'][1], longitude: self.data['position'][0], radius: self.data['radius']}
  end

  def self.aggregate_type_to_handle_type(aggregate_type)
    t = aggregate_type.to_sym

    if [:phone, :sms, :mms].include?(t)
      'phone'
    elsif [:mail, :gmail, :outlook].include?(t)
      'mail'
    else
      "#{t}"
    end
  end

  def entity_handle_type
     Aggregate.aggregate_type_to_handle_type(type)
  end

  def target_id
    # The class method #target_id is added by TargetScoped
    self.class.target_id
  end

  def add_to_intelligence_queue
    IntelligenceQueue.add(target_id, id, :aggregate)
  end

  def self.create_collection
    # create the collection for the target's aggregate and shard it
    db = RCS::DB::DB.instance.mongo_connection
    collection = db.collection self.collection.name
    # ensure indexes
    self.create_indexes
    # enable sharding only if not enabled
    RCS::DB::Shard.set_key(collection, {type: 1, day: 1, aid: 1}) unless collection.stats['sharded']
  end

  def self.versus_of_communications_with(handle)
    trace :debug, "Determining communication versus between target #{@target_id} and the handle #{handle.handle.inspect} (#{handle.type.inspect})"

    directions = self.in(:type => handle.aggregate_types).where('data.peer' => handle.handle).only('data.versus').distinct('data.versus')

    if directions.size == 1
      directions.first.to_sym
    elsif directions.size == 2
      :both
    else
      nil
    end
  end

  # Extracts the most visited urls for a given target (within a timeframe).
  # Params accepted are "from", "to" (in the form of yyyymmdd strings) and "limit" (integer).
  # @example Aggregate.most_visited_urls(target._id, 'from' => '20130103', 'to' => '20140502').
  def self.most_visited_urls(target_id, params = {})
    match = {:type => :url}
    match[:day] = {'$gte' => params['from'], '$lte' => params['to']} if params['from'] and params['to']
    limit = params['num'] || 5
    group = {_id: "$data.host", count: {"$sum" => "$count"}}

    pipeline = [{"$match" => match}, {"$group" => group}, {"$sort" => {count: -1}}, {"$limit" => limit.to_i}]

    results = Aggregate.target(target_id).collection.aggregate(pipeline)

    # Rename the "_id" key to "host" and adds the "percent" key
    total = results.inject(0) { |num, hash| num += hash["count"]; num }

    results.each do |hash|
      hash["host"] = hash["_id"]
      hash.delete("_id")
      hash["percent"] = ((hash["count"].to_f / total.to_f)*100).round(1)
    end

    results
  end

  def self.most_visited_places(target_id, params = {})
    match = {type: :position}
    match[:day] = {'$gte' => params['from'], '$lte' => params['to']} if params['from'] and params['to']
    limit = params['num'] || 5
    group = {_id: '$data.position', count: {"$sum" => "$count"}, radius: {"$min" => "$data.radius"}}
    project = {position: '$_id', _id: 0, count: 1, radius: 1}

    pipeline = [{"$match" => match}, {"$group" => group}, {"$sort" => {count: -1}}, {"$project" => project}, {"$limit" => limit.to_i}]
    results = Aggregate.target(target_id).collection.aggregate(pipeline)

    return results if results.empty?

    positions = results.map { |hash| hash['position'] }

    operation_id = ::Item.find(target_id).path.first

    positions2entities = Entity.path_include(operation_id).positions.in(position: positions).only(:position, :name).inject({}) do |hash, entity|
      hash[entity.position] = {'_id' => entity.id, 'name' => entity.name}
      hash
    end

    results.map! do |hash|
      entity = positions2entities[hash['position']]
      hash['entity'] = entity if entity
      hash
    end
  end

  def self.most_contacted(target_id, params)
    start = Time.now
    most_contacted_types = [:chat, :mail, :sms, :mms, :facebook,
                            :gmail, :skype, :bbm, :whatsapp, :msn, :adium,
                            :viber, :outlook, :wechat, :line, :phone]

    # mongoDB aggregation framework

    match = {:type => {'$in' => most_contacted_types}}
    match[:day] = {'$gte' => params['from'], '$lte' => params['to']} if params['from'] and params['to']

    pipeline = [{ "$match" => match },
                { "$group" =>
                  { _id: { peer: "$data.peer", type: "$type" },
                    count: { "$sum" => "$count" },
                    size: { "$sum" => "$size" },
                  }
                }]

    time = Time.now
    # extract the results
    contacted = Aggregate.target(target_id).collection.aggregate(pipeline)

    trace :debug, "Most contacted: Aggregation time #{Time.now - time}" if RCS::DB::Config.instance.global['PERF']

    # normalize them in a better form
    contacted.collect! {|e| {peer: e['_id']['peer'], type: e['_id']['type'], count: e['count'], size: e['size']}}

    # group them by type
    group = contacted.to_set.classify {|e| e[:type]}.values

    # sort can be 'count' or 'size'
    sort_by = params['sort'].to_sym if params['sort']
    sort_by ||= :count

    limit = params['num'].to_i - 1 if params['num']
    limit ||= 4

    # sort the most contacted and cut the first N (also calculate the percentage)
    top = group.collect do |set|
      total = set.inject(0) {|sum, e| sum + e[sort_by]}
      next if total == 0
      set.each {|e| e[:percent] = (e[sort_by] * 100 / total).round(1)}
      set.sort {|x,y| x[sort_by] <=> y[sort_by]}.reverse.slice(0..limit)
    end

    time = Time.now

    # resolve the names of the peer from the db of entities
    top.each do |t|
      t.each do |e|
        e[:peer_name] = Entity.name_from_handle(e[:type], e[:peer], target_id)
        e.delete(:peer_name) unless e[:peer_name]
      end
    end

    trace :debug, "Most contacted: Resolv time #{Time.now - time}" if RCS::DB::Config.instance.global['PERF']

    return top
  end
end
