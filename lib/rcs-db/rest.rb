#
# The REST interface for all the rest Objects
#

# relatives
require_relative 'sessions.rb'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'json'

module RCS
module DB

class RESTController
  include RCS::Tracer

  STATUS_OK = 200
  STATUS_NOT_FOUND = 404
  STATUS_NOT_AUTHORIZED = 403

  # the parameters passed on the REST request
  attr_accessor :params

  def init(http_headers, req_method, req_uri, req_cookie, req_content)

    # check the authentication
    if req_cookie.nil? then
      # extract the name of the controller and the parameters
      root, controller_name, *params = req_uri.split('/')
      # if the request does not contains any cookies, the only allowed method is AuthController::login
      return false unless controller_name.capitalize.eql? 'Auth' and params.first.eql? 'login'
    else
      # we have a cookie, check if it's valid
      if not SessionManager.instance.check(req_cookie) then
        trace :warn, "[#{@peer}][#{cookie}] Invalid cookie"
        return false
      end
    end

    @http_headers = http_headers
    @req_method = req_method
    @req_uri = req_uri
    @req_cookie = req_cookie
    @req_content = req_content
    # the parsed http parameters (from uri and from content)
    @params = {}

    return true
  end

  def cleanup
    # hook method if you need to perform some cleanup operation
  end

  # helper method for the replies
  def json_reply(reply)
    return reply.to_json, 'application/json'
  end

  def create
    # POST /object
  end

  def index
    # GET /object
  end

  def show
    # GET /object/id
  end

  def update
    # PUT /object/id
  end

  def destroy
    # DELETE /object/id
  end

  # everything else is a method name
  # for example:
  # GET /object/method
  # will invoke :method on the ObjectController instance

end

end #DB::
end #RCS::

require_relative 'rest/auth'
require_relative 'rest/user'