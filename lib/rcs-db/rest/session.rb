#
# Controller for the Sessions
#

require_relative '../push'

require 'digest/sha1'

module RCS
module DB

class SessionController < RESTController

  def index
    require_auth_level :admin

    list = []
    # the console needs sessions with the User object inside
    # so, we have to reconstruct a fake list here
    SessionManager.instance.all.each do |sess|

      # create a fake object with a real user reference
      session = {}
      session[:user] = ::User.where({_id: sess[:user].first}).first
      session[:level] = sess[:level]
      session[:address] = sess[:address]
      session[:cookie] = sess[:cookie]
      session[:time] = sess[:time]
      list << session
    end

    return ok(list)
  end
  
  def destroy
    require_auth_level :admin
    
    session_id = @params['_id']
    session = SessionManager.instance.get(session_id)

    return not_found if session.nil?

    PushManager.instance.notify('logout', {rcpt: session[:user][:_id], text: "You were disconnected by #{@session[:user][:name]}"})

    return not_found unless SessionManager.instance.delete(session_id)

    Audit.log :actor => @session[:user][:name], :action => 'session.destroy', :desc => "Killed the session of the user '#{session[:user][:name]}'"

    return ok
  end

end

end #DB::
end #RCS::