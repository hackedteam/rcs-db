
# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class RESTController
  include RCS::Tracer

  # the parameters passed on the REST request
  attr_accessor :params

  def init(http_headers, req_method, req_uri, req_cookie, req_content)
    @http_headers = http_headers
    @req_method = req_method
    @req_uri = req_uri
    @req_cookie = req_cookie
    @req_content = req_content
    # the parsed http parameters (from uri and from content)
    @params = {}
  end

  def cleanup
    
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