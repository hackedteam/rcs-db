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
  def process_request(headers, request)
    
    # extract the name of the controller and the parameters
    root, controller_name, *params = request[:uri].split('/')
    
    # instantiate the correct AnythingController class
    # we will then pass the control of the operation to that object
    controller = RESTController.get_controller(controller_name, headers, request, params)
    if controller.nil?
      trace :error, "Invalid controller [#{request[:uri]}]"
      return RESTController.not_found
    end
    
    # init the controller and check if everything is ok to proceed
    return RESTController.not_authorized 'AUTH_REQUIRED' unless controller.valid_request?
    
    # invoke the controller
    begin
      response = controller.act!
    rescue NotAuthorized => e
      response = RESTController.not_authorized 'INVALID_ACCESS_LEVEL'
      trace :warn, "Invalid access level: " + e.message
    end
    
    # the controller job has finished, call the cleanup hook
    controller.cleanup
    
    # paranoid check
    return RESTController.not_authorized('CONTROLLER_ERROR') if response.nil?
    return response
  end

  # helper method for the replies
  def json_reply(reply)
    return reply.to_json, 'application/json'
  end
  
end #Parser

end #DB::
end #RCS::