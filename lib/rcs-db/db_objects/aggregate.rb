require 'mongoid'
require 'set'

require_relative '../position/proximity'

#module RCS
#module DB

class Aggregate
  extend RCS::Tracer
  include Mongoid::Document
  include RCS::DB::Proximity

  field :aid, type: String                      # agent BSON_ID
  field :day, type: String                      # day of aggregation
  field :type, type: Symbol
  field :count, type: Integer, default: 0
  field :size, type: Integer, default: 0        # seconds for calls, bytes for the others
  field :info, type: Array                      # for summary or timeframe (position

  field :data, type: Hash, default: {}

  store_in collection: -> { self.collection_name }

  index({aid: 1}, {background: true})
  index({type: 1}, {background: true})
  index({day: 1}, {background: true})
  index({"data.peer" => 1}, {background: true})
  index({"data.type" => 1}, {background: true})
  index({type: 1, "data.peer" => 1 }, {background: true})

  index({'data.position' => "2dsphere"}, {background: true})

  shard_key :type, :day, :aid

  scope :positions, where(type: :position)

  # The "day" attribute must be a string in the format of YYYYMMDD
  # or the string "0" (when the type if :postioner or :summary)
  validates_format_of :day, :with => /\A(\d{8}|0)\z/

  def to_point
    raise "not a position" unless type.eql? :position
    time_params = (info.last.symbolize_keys rescue nil) || {}
    Point.new time_params.merge(lat: data['position'][1], lon: data['position'][0], r: data['radius'])
  end

  def self.summary_include? type, peer
    summary = self.where(day: '0', type: :summary).first
    return false unless summary

    # type can be an array of types
    type = [type].flatten

    type.each do |t|
      return true if summary.info.include? "#{t}_#{peer}"
    end

    false
  end

  def self.add_to_summary(type, peer)
    summary = self.where(day: '0', aid: '0', type: :summary).first_or_create!
    summary.add_to_set(:info, type.to_s + '_' + peer.to_s)
  end

  def self.rebuild_summary
    return if self.empty?

    # get all the tuple (type, peer)
    pipeline = [{ "$match" => {:type => {'$nin' => [:summary]} }},
                { "$group" =>
                  { _id: { peer: "$data.peer", type: "$type" }}
                }]
    data = self.collection.aggregate(pipeline)

    return if data.empty?

    # normalize them in a better form
    data.collect! {|e| e['_id']['type'].to_s + '_' + e['_id']['peer']}

    summary = self.where(day: '0', aid: '0', type: :summary).first_or_create!

    summary.info = data
    summary.save!
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

  def self.target target
    target_id = target.respond_to?(:id) ? target.id : target
    dynamic_classname = "Aggregate#{target_id}"

    if const_defined? dynamic_classname
      const_get dynamic_classname
    else
      const_set dynamic_classname, Class.new(Aggregate) { @target_id = target_id }
    end
  end

  # Prevent people from calling Aggregate.new instead of Aggregate.target(...).new
  def initialize *args
    collection_name
    super
  end

  def self.collection_name
    raise "Missing target id. Maybe you're trying to instantiate Aggregate without using Aggregate#target." unless @target_id
    "aggregate.#{@target_id}"
  end

  def self.most_contacted(target_id, params)
    start = Time.now

    most_contacted_types = [:call, :chat, :mail, :sms, :mms, :facebook, :gmail, :skype, :bbm, :whatsapp, :msn, :adium, :viber]

    #
    # Map Reduce has some downsides
    # let's try if the Mongo::Aggregation framework is better...
    #
=begin
    # emit count and size for each tuple of peer/type
    map = "function() {
             emit({peer: this.data.peer, type: this.type}, {count: this.count, size: this.size});
          }"

    # sum each value grouping them by key(peer, type)
    reduce = "function(key, values) {
                var sum_count = 0;
                var sum_size = 0;
                values.forEach(function(e) {
                    sum_count += e.count;
                    sum_size += e.size;
                  });
                return {count: sum_count, size: sum_size};
              };"

    # from/to period to consider
    options = {:query => {:day => {'$gte' => params['from'], '$lte' => params['to']}, :type => {'$in' => most_contacted_types} },
               :out => {:inline => 1}, :raw => true }

    # execute the map reduce job
    reduced = collection.map_reduce(map, reduce, options)
    # extract the results
    contacted = reduced['results']
    # normalize them in a better form
    contacted.collect! {|e| {peer: e['_id']['peer'], type: e['_id']['type'], count: e['value']['count'], size: e['value']['size']}}

    #trace :debug, reduced['results']
    #trace :debug, ""
=end

    #
    # Aggregation Framework is better...
    #
    pipeline = [{ "$match" => {:day => {'$gte' => params['from'], '$lte' => params['to']}, :type => {'$in' => most_contacted_types} }},
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

  def position
    {latitude: self.data['position'][1], longitude: self.data['position'][0], radius: self.data['radius']}
  end

  def entity_handle_type
    t = self.type.to_sym

    if [:call, :sms, :mms].include? t
      'phone'
    elsif [:mail, :gmail].include? t
      'mail'
    else
      "#{t}"
    end
  end
end

#end # ::DB
#end # ::RCS
