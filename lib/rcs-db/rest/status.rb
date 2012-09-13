#
# Controller for the User objects
#

module RCS
module DB

class StatusController < RESTController

  # retrieve the list of all components with their status
  def index
    require_auth_level :admin, :sys, :tech, :view

    mongoid_query do
      result = ::Status.all

      return ok(result)
    end
  end

  # insert or update an entry in the DB,
  # every component uses this to report its status
  def create
    require_auth_level :server
    
    # the ip address is not specified, we take the peer address
    @params['address'] = @request[:peer] if @params['address'] == ''
    
    # save the status to the db
    stats = {:disk => @params['disk'], :cpu => @params['cpu'], :pcpu => @params['pcpu']}
    ::Status.status_update @params['name'], @params['address'], @params['status'], @params['info'], stats, @params['type'], @params['version']
    
    return ok
  end

  # delete an entry in the DB,
  # used when you uninstall a component and don't want the warning anymore
  def destroy
    require_auth_level :sys

    mongoid_query do
      monitor = ::Status.find(@params['_id'])
      name = monitor[:name]
      monitor.destroy

      Audit.log :actor => @session[:user][:name], :action => 'monitor.delete', :desc => "Component '#{name}' was deleted from db"

      return ok
    end
  end

  # returns the counters grouped by status
  def counters
    require_auth_level :admin, :sys, :tech, :view
    
    counters = {:ok => 0, :warn => 0, :error => 0}

    mongoid_query do
      counters[:ok] = ::Status.count(conditions: {status: '0'})
      counters[:warn] = ::Status.count(conditions: {status: '1'})
      counters[:error] = ::Status.count(conditions: {status: '2'})

      return ok(counters)
    end
  end

end

end #DB::
end #RCS::