#
# Controller for the Sessions
#

require 'digest/sha1'

module RCS
module DB

class SessionController < RESTController

  def index
    require_auth_level :admin

    return RESTController.ok(SessionManager.instance.all)
  end

  def destroy
    require_auth_level :admin
    
    session = SessionManager.instance.get(params['session'])
    Audit.log :actor => @session[:user][:name], :action => 'session.destroy', :desc => "Killed the session of the user '#{session[:user][:name]}'"

    return RESTController.not_found unless SessionManager.instance.delete(params['session'])
    return RESTController.ok
  end

end

end #DB::
end #RCS::