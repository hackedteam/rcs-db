#
#  HTTP requests parsing module
#

# relatives
require_relative 'rest'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/mime'

# system
require 'cgi'
require 'json'

module RCS
module DB

module Parser
  include RCS::Tracer

  # parse a request from a client
  def http_parse(http_headers, req_method, req_uri, req_cookie, req_content, req_query)
    
    # extract the name of the controller and the parameters
    root, controller_name, *params = req_uri.split('/')

    # instantiate the correct AnythingController class
    # we will then pass the control of the operation to that object
    begin
      klass = "#{controller_name.capitalize}Controller" unless controller_name.nil?
      controller = eval(klass).new
    rescue
      trace :error, "Invalid controller [#{req_uri}]"
      return RESTController.not_found
    end
    
    # init the controller and check if everything is ok to proceed
    if not controller.init(http_headers, req_method, req_uri, req_cookie, req_content, @peer) then
      return RESTController.not_authorized 'AUTH_REQUIRED'
    end
    
    # if the object has an explicit method calling
    method = params.shift if not params.first.nil? and controller.respond_to?(params.first)
  
    # save the params in the controller object
    controller.params[controller_name.downcase] = params.first unless params.first.nil?
    controller.params.merge!(CGI::parse(req_query)) unless req_query.nil?
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
      response = controller.send(method) unless method.nil?
    rescue NotAuthorized => e
      response = RESTController.not_authorized 'INVALID_ACCESS_LEVEL'
      trace :warn, "Invalid access level: " + e.message
    rescue Exception => e
      response.content = "ERROR: " + e.message unless response.nil?
      #resp_content = "ERROR: " + e.message
      trace :error, response.content unless response.nil?
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    # the controller job has finished, call the cleanup hook
    controller.cleanup
    
    # paranoid check
    return RESTController.not_authorized('CONTROLLER_ERROR') if response.nil?
    return response
  end
  
  # returns the JSON parsed object containing the parameters passed to a POST or PUT request
  def http_parse_parameters(content)
    return {} if content.nil?
    begin
      # in case the content is binary and not a json document
      # we will catch the exception and return the empty hash {}
      result = JSON.parse(content)
      return result
    rescue Exception => e
      #trace :debug, "#{e.class}: #{e.message}"
      return {}
    end
  end

  # helper method for the replies
  def json_reply(reply)
    return reply.to_json, 'application/json'
  end
  
end #Parser

end #DB::
end #RCS::