#
# Controller for the Auth objects
#

module RCS
module DB

class AuthController < RESTController

  def login
    case @req_method
      when 'GET'
        # return the info about the current auth session
        sess = SessionManager.instance.get(@req_cookie)
        return if sess.nil?
        return STATUS_OK, *json_reply(sess)

      when 'POST'
        #TODO: authenticate the user
        cookie = SessionManager.instance.create(1, @params['user'], :admin)
        sess = SessionManager.instance.get(cookie)
        return STATUS_OK, *json_reply(sess), cookie
    end

    return STATUS_NOT_AUTHORIZED
  end


  def logout
    SessionManager.instance.delete(@req_cookie)
    return STATUS_OK
  end

end

end #DB::
end #RCS::