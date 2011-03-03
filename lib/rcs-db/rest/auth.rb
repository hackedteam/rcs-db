#
# Controller for the Auth objects
#

require 'json'

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
        return STATUS_OK, *json_reply({:cookie => cookie}), cookie
    end
  end


  def logout
    SessionManager.instance.delete(@req_cookie)
    return STATUS_OK
  end

end

end #DB::
end #RCS::