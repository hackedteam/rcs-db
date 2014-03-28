#
# Controller for the Auth objects
#

require_relative '../auth'

module RCS
module DB

class AuthController < RESTController

  bypass_auth [:login, :logout, :reset]

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
        version = @params['version']
        type = @params['type']

        begin

          # check if it's a collector logging in
          unless (sess = AuthManager.instance.auth_server(user, pass, version, type, @request[:peer])).nil?
            return ok(sess, {cookie: 'session=' + sess[:cookie] + '; path=/;'})
          end

          # otherwise check if it's a normal user
          unless (sess = AuthManager.instance.auth_user(user, pass, version, @request[:peer])).nil?
            # append the cookie to the other that may have been present in the request
            expiry = (Time.now() + 7*86400).strftime('%A, %d-%b-%y %H:%M:%S %Z')
            trace :debug, "[#{@request[:peer]}] Issued cookie with expiry time: #{expiry}"

            # retro compatibility with the console
            sess[:user] = sess.user

            return ok(sess, {cookie: 'session=' + sess[:cookie] + "; path=/; expires=#{expiry}" })
          end

        rescue Exception => e
          trace :error, "#{e.message}"
          trace :error, "#{e.backtrace}"

          if e.message =~ /password expired/i
            return not_authorized("EXPIRED_ACCOUNT")
          else
            return conflict('LICENSE_LIMIT_REACHED')
          end
        end

    end
    
    not_authorized("INVALID_ACCOUNT")
  end

  # this method is used to create (or recreate) the admin
  # it can be used without auth but only from localhost
  def reset

    return not_authorized("can only be used locally") unless @request[:peer].eql? '127.0.0.1'

    mongoid_query do
      username, password = @params['user'], @params['pass']

      user = User.where(name: username).first

      # Create the admin user if is missing
      if username == 'admin' and !user
        DB.instance.ensure_admin
        user = User.where(name: username).first
      elsif !user
        return not_found("User not found")
      end

      trace :info, "Resetting #{username.inspect} password"

      user.pass = password

      if !user.save
        return server_error(user.errors.values.join(", "))
      end

      Audit.log :actor => '<system>', :action => 'auth.reset', :user_name => username, :desc => "Password reset"
    end

    ok("Password changed")
  end

  # once the session is over you can explicitly logout
  def logout
    if @session
      Audit.log :actor => @session.user[:name], :action => 'logout', :user_name => @session.user[:name], :desc => "User '#{@session.user[:name]}' logged out"
      SessionManager.instance.delete(@request[:cookie])
    end
    
    ok('', {cookie: "session=; path=/; expires=#{Time.at(0).strftime('%A, %d-%b-%y %H:%M:%S %Z')}" })
  end

end

end #DB::
end #RCS::