#
# Controller for the Auth objects
#

require 'rcs-db/config'

module RCS
module DB

class AuthController < RESTController

  def initialize
    @auth_level = [:none]
  end

  def login
    case @req_method
      # return the info about the current auth session
      when 'GET'
        sess = SessionManager.instance.get(@req_cookie)
        return if sess.nil?
        return STATUS_OK, *json_reply(sess)

      # authenticate the user
      when 'POST'
        # if the user is a Collector, it will authenticate with a unique username
        # and the password must be the 'server signature'
        # the unique username will be used to create an entry for it in the network schema
        if auth_server(@params['user'], @params['pass']) or auth_user(@params['user'], @params['pass'])
          cookie = SessionManager.instance.create(1, @params['user'], @auth_level)
          sess = SessionManager.instance.get(cookie)
          return STATUS_OK, *json_reply(sess), cookie
        end
    end

    return STATUS_NOT_AUTHORIZED
  end

  def logout
    SessionManager.instance.delete(@req_cookie)
    return STATUS_OK
  end


  def auth_server(user, pass)
    server_sig = File.read(Config.file('SERVER_SIG')).chomp

    # the Collectors are authenticated only by the server signature
    if pass.eql? server_sig
      #TODO: insert the unique username in the network list
      trace :info, "Collector [#{user}] logged in"
      @auth_level = [:server]
      return true
    end

    return false
  end

  def auth_user(user, pass)

    u = DB.user_find(user)

    # user not found
    if u.empty?
      trace :warn, "User [#{user}] NOT FOUND"
      return false
    end

    # check the password
    if DB.user_check_pass(pass, u['pass']) then
      @auth_level = u['level']
      return true
    end

    trace :warn, "User [#{user}] INVALID PASSWORD"
    return false
  end

end

end #DB::
end #RCS::