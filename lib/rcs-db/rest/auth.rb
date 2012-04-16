#
# Controller for the Auth objects
#

module RCS
module DB

class AuthController < RESTController

  bypass_auth [:login, :logout, :reset]

  def initialize
    @auth_level = []
  end
  
  # everyone who wants to use the system must first authenticate with this method
  def login
    case @request[:method]
      # return the info about the current auth session
      when 'GET'
        sess = SessionManager.instance.get(@request[:cookie])
        return not_authorized if sess.nil?
        return ok(sess)
      
      # authenticate the user
      when 'POST'
        
        user = @params['user']
        pass = @params['pass']

        begin
          # if the user is a Collector, it will authenticate with a unique username
          # and the password must be the 'server signature'
          # the unique username will be used to create an entry for it in the network schema
          if auth_server(user, pass)
            # create the new auth sessions
            sess = SessionManager.instance.create({:name => user}, @auth_level, @request[:peer])
            # append the cookie to the other that may have been present in the request
            return ok(sess, {cookie: 'session=' + sess[:cookie] + '; path=/;'})
          end
        rescue Exception => e
          return conflict('LICENSE_LIMIT_REACHED')
        end
        
        # normal user login
        if auth_user(user, pass)
          # we have to check if it was already logged in
          # in this case, invalidate the previous session
          sess = SessionManager.instance.get_by_user(user)
          unless sess.nil?
            Audit.log :actor => user, :action => 'logout', :user_name => user, :desc => "User '#{user}' forcibly logged out by system"
            PushManager.instance.notify('message', {rcpt: sess[:user][:_id], text: "Your account has been used on another machine"})
            SessionManager.instance.delete(sess[:cookie])
          end
          
          Audit.log :actor => user, :action => 'login', :user_name => user, :desc => "User '#{user}' logged in"

          trace :info, "[#{@request[:peer]}] Auth login: #{user}"

          # get the list of accessible Items
          accessible = SessionManager.instance.get_accessible @user
          # create the new auth sessions
          sess = SessionManager.instance.create(@user, @auth_level, @request[:peer], accessible)
          # append the cookie to the other that may have been present in the request
          expiry = (Time.now() + 86400).strftime('%A, %d-%b-%y %H:%M:%S %Z')
          trace :debug, "Issued cookie with expiry time: #{expiry}"
          # don't return the accessible items (used only internally)
          session = sess.select {|k,v| k != :accessible}
          return ok(session, {cookie: 'session=' + sess[:cookie] + "; path=/; expires=#{expiry}" })
        end
    end
    
    not_authorized("invalid account")
  end

  # this method is used to create (or recreate) the admin
  # it can be used without auth but only from localhost
  def reset

    return not_authorized("can only be used locally") unless @request[:peer].eql? '127.0.0.1'

    mongoid_query do
      user = User.where(name: 'admin').first

      # user not found, create it
      if user.nil?
        DB.instance.ensure_admin
        user = User.where(name: 'admin').first
      end
      
      trace :info, "Resetting password for user 'admin'"
      Audit.log :actor => '<system>', :action => 'auth.reset', :user_name => 'admin', :desc => "Password reset"
      user.create_password(@params['pass'])
      user.save
    end
    
    ok("Password reset for user 'admin'")
  end

  # once the session is over you can explicitly logout
  def logout
    if @session
      Audit.log :actor => @session[:user][:name], :action => 'logout', :user_name => @session[:user][:name], :desc => "User '#{@session[:user][:name]}' logged out"
      SessionManager.instance.delete(@request[:cookie])
    end
    
    ok('', {cookie: "session=; path=/; expires=#{Time.at(0).strftime('%A, %d-%b-%y %H:%M:%S %Z')}" })
  end
  
  private
  # private method to authenticate a server
  def auth_server(user, pass)
    server_sig = ::Signature.where({scope: 'server'}).first

    # the Collectors are authenticated only by the server signature
    if pass.eql? server_sig['value']

      # take the external ip address from the username
      instance, version, address = user.split(':')
      Collector.collector_login instance, version, address, @request[:peer]
      
      trace :info, "Collector [#{user}] logged in"
      @auth_level = [:server]
      return true
    end
    
    return false
  end

  # method for user authentication
  def auth_user(username, pass)
    @user = User.where(name: username).first

    # user not found
    if @user.nil?
      Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "User '#{username}' not found"
      trace :warn, "User [#{username}] NOT FOUND"
      return false
    end

    # the account is valid
    if @user.verify_password(pass)
      # symbolize the privs array
      @user[:privs].each do |p|
        @auth_level << p.downcase.to_sym
      end
      return true
    end
    
    Audit.log :actor => username, :action => 'login', :user_name => username, :desc => "Invalid password for user '#{username}'"
    trace :warn, "User [#{username}] INVALID PASSWORD"
    return false
  end

end

end #DB::
end #RCS::