#
# Controller for the User objects
#

module RCS
module DB

class StatusController < RESTController

  # retrieve the list of all components with their status
  def index
    require_auth_level :admin, :tech, :viewer

    mongoid_query do
      result = ::Status.all

      return RESTController.ok(result)
    end
  end

  # insert or update an entry in the DB,
  # every component uses this to report its status
  def create
    require_auth_level :server
    
    # the ip address is not specified, we take the peer address
    if @params['address'] == '' then
      @params['address'] = @request[:peer]
    end
    
    # save the status to the db
    stats = {:disk => @params['disk'], :cpu => @params['cpu'], :pcpu => @params['pcpu']}
    ::Status.status_update @params['name'], @params['address'], @params['status'], @params['info'], stats
    
    return RESTController.ok
  end

  # delete an entry in the DB,
  # used when you uninstall a component and don't want the warning anymore
  def destroy
    require_auth_level :admin

    mongoid_query do
      monitor = ::Status.find(@params['status'])
      name = monitor[:name]
      monitor.destroy

      Audit.log :actor => @session[:user][:name], :action => 'monitor.delete', :desc => "Component '#{name}' was deleted from db"

      return RESTController.ok
    end
  end

  # returns the counters grouped by status
  def counters
    require_auth_level :admin, :tech, :viewer
    
    counters = {:ok => 0, :warn => 0, :error => 0}

    mongoid_query do
      counters[:ok] = ::Status.count(conditions: {status: '0'})
      counters[:warn] = ::Status.count(conditions: {status: '1'})
      counters[:error] = ::Status.count(conditions: {status: '2'})

      return RESTController.ok(counters)
    end
  end

end

end #DB::
end #RCS::