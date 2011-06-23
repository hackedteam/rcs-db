#
# Controller for the Sessions
#

require 'digest/sha1'

module RCS
module DB

class SessionController < RESTController

  def index
    require_auth_level :admin

    return RESTController.reply.ok(SessionManager.instance.all)
  end
  
  def destroy
    require_auth_level :admin
    
    session_id = @params['_id']
    session = SessionManager.instance.get(session_id)
    return RESTController.reply.not_found if session.nil?
    
    Audit.log :actor => @session[:user][:name], :action => 'session.destroy', :desc => "Killed the session of the user '#{session[:user][:name]}'"
    
    return RESTController.reply.not_found unless SessionManager.instance.delete(session_id)
    return RESTController.reply.ok
  end

end

end #DB::
end #RCS::