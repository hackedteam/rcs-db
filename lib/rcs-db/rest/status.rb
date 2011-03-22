#
# Controller for the User objects
#

module RCS
module DB

class StatusController < RESTController

  # retrieve the list of all components with their status
  def index
    require_auth_level :admin, :tech, :viewer

    result = DB.status_get

    return STATUS_OK, *json_reply(result)
  end

  # insert or update an entry in the DB,
  # every component uses this to report its status
  def create
    require_auth_level :server

    # the ip address is not specified, we take the peer address
    if params['ip'] == '' then
      params['ip'] = @req_peer
    end

    # save the status to the db
    stats = {:disk => params['disk'], :cpu => params['cpu'], :pcpu => params['pcpu']}
    DB.status_update params['component'], params['ip'], params['status'], params['message'], stats

    return STATUS_OK
  end

  # delete an entry in the DB,
  # used when you uninstall a component and don't want the warning anymore
  def destroy
    require_auth_level :admin

    DB.status_del params[:status]

    Audit.log :actor => @session[:user], :action => 'monitor delete', :desc => "Component #{params[:status]} was deleted from db"
        
    return STATUS_OK
  end

end

end #DB::
end #RCS::