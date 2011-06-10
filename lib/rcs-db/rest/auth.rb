#
# Controller for the Auth objects
#

module RCS
module DB

class AuthController < RESTController

  def initialize
    @auth_level = []
  end

  # everyone who wants to use the system must first authenticate with this method
  def login
    case @req_method
      # return the info about the current auth session
      when 'GET'
        sess = SessionManager.instance.get(@session_cookie)
        return STATUS_NOT_AUTHORIZED if sess.nil?
        return STATUS_OK, *json_reply(sess)

      # authenticate the user
      when 'POST'
        begin
          # if the user is a Collector, it will authenticate with a unique username
          # and the password must be the 'server signature'
          # the unique username will be used to create an entry for it in the network schema
          if auth_server(@params['user'], @params['pass'])
            # create the new auth sessions
            sess = SessionManager.instance.create({:name => @params['user']}, @auth_level, @req_peer)
            # append the cookie to the other that may have been present in the request
            return STATUS_OK, *json_reply(sess), 'session=' + sess[:cookie] + '; path=/;'
          end
        rescue Exception => e
          return STATUS_CONFLICT, *json_reply('LICENSE_LIMIT_REACHED')
        end

        
        # normal user login
        if auth_user(@params['user'], @params['pass'])
          # we have to check if it was already logged in
          # in this case, invalidate the previous session
          sess = SessionManager.instance.get_by_user(@params['user'])
          unless sess.nil? then
            Audit.log :actor => @params['user'], :action => 'logout', :user => @params['user'], :desc => "User '#{@params['user']}' forcibly logged out by system"
            SessionManager.instance.delete(sess[:cookie])
          end

          Audit.log :actor => @params['user'], :action => 'login', :user => @params['user'], :desc => "User '#{@params['user']}' logged in"

          # create the new auth sessions
          sess = SessionManager.instance.create(@user, @auth_level, @req_peer)
          # append the cookie to the other that may have been present in the request
          expiry = (Time.now() + 86400).strftime('%A, %d-%b-%y %H:%M:%S %Z')
          trace :debug, "Issued cookie with expiry time: #{expiry}"
          return STATUS_OK, *json_reply(sess), 'session=' + sess[:cookie] + "; path=/; expires=#{expiry}"
        end

    end

    return STATUS_NOT_AUTHORIZED, "invalid account"
  end

  # once the session is over you can explicitly logout
  def logout
    Audit.log :actor => @session[:user][:name], :action => 'logout', :user => @session[:user][:name], :desc => "User '#{@session[:user][:name]}' logged out"
    SessionManager.instance.delete(@session_cookie)
    return STATUS_OK, '', 'text/html', "session=; path=/; expires=#{Time.at(0).strftime('%A, %d-%b-%y %H:%M:%S %Z')}"
  end
  

  # private method to authenticate a server
  def auth_server(user, pass)
    server_sig = File.read(Config.instance.file('SERVER_SIG')).chomp

    # the Collectors are authenticated only by the server signature
    if pass.eql? server_sig

      Collector.collector_login user, @req_peer

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
      Audit.log :actor => username, :action => 'login', :user => username, :desc => "User '#{username}' not found"
      trace :warn, "User [#{username}] NOT FOUND"
      return false
    end

    # the account is valid
    if @user.verify_password(pass) then
      # symbolize the privs array
      @user[:privs].each do |p|
        @auth_level << p.downcase.to_sym
      end
      return true
    end
    
    Audit.log :actor => username, :action => 'login', :user => username, :desc => "Invalid password for user '#{username}'"
    trace :warn, "User [#{username}] INVALID PASSWORD"
    return false
  end

end

end #DB::
end #RCS::