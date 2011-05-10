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

    # extract the name of the controller and the parameters
    root, controller_name, *params = req_uri.split('/')

    # instantiate the correct AnythingController class
    # we will then pass the control of the operation to that object
    begin
      klass = "#{controller_name.capitalize}Controller" unless controller_name.nil?
      controller = eval(klass).new
    rescue
      trace :error, "Invalid controller [#{req_uri}]"
      return RESTController::STATUS_NOT_FOUND
    end

    # init the controller and check if everything is ok to proceed
    if not controller.init(http_headers, req_method, req_uri, req_cookie, req_content, @peer) then
      return RESTController::STATUS_NOT_AUTHORIZED
    end

    # if the object has an explicit method calling
    method = params.shift if not params.first.nil? and controller.respond_to?(params.first)

    #trace :debug, req_content

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

    # default is not authorized to do anything
    resp_status = RESTController::STATUS_NOT_AUTHORIZED

    # invoke the right method on the controller
    begin
      resp_status, resp_content, resp_content_type, resp_cookie = controller.send(method) unless method.nil?
    rescue NotAuthorized => e
      resp_content = "Invalid access level: " + e.message
      trace :warn, resp_content
    rescue Exception => e
      resp_content = "ERROR: " + e.message
      trace :error, resp_content
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    # paranoid check
    resp_status = RESTController::STATUS_NOT_AUTHORIZED if resp_status.nil?

    # the controller job has finished, call the cleanup hook
    controller.cleanup

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

end #Parser

end #DB::
end #RCS::