#
# Controller for the User objects
#

module RCS
module DB

class StatusController < RESTController

  # retrieve the list of all components with their status
  def index
    require_auth_level :admin, :tech, :viewer

    result = ::Status.all

    return STATUS_OK, *json_reply(result)
  end

  # insert or update an entry in the DB,
  # every component uses this to report its status
  def create
    require_auth_level :server

    # the ip address is not specified, we take the peer address
    if params['address'] == '' then
      params['address'] = @req_peer
    end

    # save the status to the db
    stats = {:disk => params['disk'], :cpu => params['cpu'], :pcpu => params['pcpu']}
    DB.instance.status_update params['name'], params['address'], params['status'], params['info'], stats

    return STATUS_OK
  end

  # delete an entry in the DB,
  # used when you uninstall a component and don't want the warning anymore
  def destroy
    require_auth_level :admin

    monitor = ::Status.find(params['status'])
    name = monitor[:name]
    monitor.destroy
    
    Audit.log :actor => @session[:user][:name], :action => 'monitor.delete', :desc => "Component '#{name}' was deleted from db"
        
    return STATUS_OK
  end

  # returns the counters grouped by status
  def counters
    counters = {:ok => 0, :warn => 0, :error => 0}

    counters[:ok] = ::Status.count(conditions: {status: '0'})
    counters[:warn] = ::Status.count(conditions: {status: '1'})
    counters[:error] = ::Status.count(conditions: {status: '2'})

    return STATUS_OK, *json_reply(counters)
  end

end

end #DB::
end #RCS::