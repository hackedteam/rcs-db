#
# Controller for the Evidence objects
#

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

  def create
    require_auth_level :server

    trace :debug, "CREATE #{params}"

    return STATUS_OK, *json_reply({:bytes => @req_content.size})
  end

end

end #DB::
end #RCS::