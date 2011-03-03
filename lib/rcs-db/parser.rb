#
#  HTTP requests parsing module
#

# relatives
require_relative 'rest.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/mime'

# system
require 'json'

module RCS
module DB

module Parser
  include RCS::Tracer

  # parse a request from a client
  def http_parse(http_headers, req_method, req_uri, req_cookie, req_content)

    # by default you are not authorized to do anything
    resp_status = 403
    resp_content = nil
    resp_content_type = nil
    resp_cookie = nil

    # extract the name of the controller and the parameters
    root, controller_name, *params = req_uri.split('/')

    # check the authentication
    if req_cookie.nil? then
      # if the request does not contains any cookies, the only allowed method is auth/login
      return RESTController::STATUS_NOT_AUTHORIZED unless controller_name.capitalize.eql? 'Auth' and params.first.eql? 'login'
    else
      # we have a cookie, check if it's valid
      return RESTController::STATUS_NOT_AUTHORIZED unless valid_authentication(req_cookie)
    end

    # instantiate the correct AnythingController class
    # we will then pass the control of the operation to that object
    begin
      klass = "#{controller_name.capitalize}Controller" unless controller_name.nil?
      controller = eval(klass).new
    rescue
      trace :error, "Invalid controller [#{req_uri}]"
      return resp_status, resp_content, resp_content_type, resp_cookie
    end

    # save the parameters inside the controller
    controller.init(http_headers, req_method, req_uri, req_cookie, req_content)

    # if the object has an explicit method calling
    method = params.shift if not params.first.nil? and controller.respond_to?(params.first)

    # save the params in the controller object
    controller.params[controller_name.downcase.to_sym] = params.first unless params.first.nil?
    controller.params.merge!(http_parse_parameters(req_content))

    # if we are not calling an explicit method, extract it from the http method
    if method.nil? then
      case req_method
        when 'GET'
          method = (params.empty?) ? :index : :show 

        when 'POST'
          method = :create

        when 'PUT'
          method = :update

        when 'DELETE'
          method = :destroy
      end
    end

    # invoke the right method on the controller
    begin
      status, content, content_type, cookie = controller.send(method) unless method.nil?
    rescue Exception => e
      trace :error, "ERROR: " + e.message
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    # the controller work has finished
    controller.cleanup

    resp_status = status unless status.nil?
    resp_content = content unless content.nil?
    resp_content_type = content_type unless content_type.nil?
    resp_cookie = cookie unless cookie.nil?

    return resp_status, resp_content, resp_content_type, resp_cookie
  end

  # returns the JSON parsed object containing the parameters passed to a POST or PUT request
  def http_parse_parameters(content)
    begin
      # in case the content is binary and not a json document
      # we will catch the exception and return the empty hash {}
      return JSON.parse(content)
    rescue
      return {}
    end
  end

  def valid_authentication(cookie)
    # check if the cookie was created correctly and if it is still valid
    valid = SessionManager.instance.check(cookie)
    trace :warn, "[#{@peer}][#{cookie}] Invalid cookie" unless valid
    return valid
  end
end #Parser

end #Collector::
end #RCS::