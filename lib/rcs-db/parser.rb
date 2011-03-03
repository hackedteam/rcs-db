#
#  HTTP requests parsing module
#

# relatives
require_relative 'rest.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/mime'


module RCS
module DB

module Parser
  include RCS::Tracer

  # parse a request from a client
  def http_parse(http_headers, req_method, req_uri, req_cookie, req_content)

    # default values
    resp_content = nil
    resp_content_type = 'text/html'
    resp_cookie = nil
    # by default you are not authorized to do anything
    resp_status = 403

    # extract the name of the controller and the parameters
    root, controller, *params = req_uri.split('/')

    begin
      # instantiate the correct AnythingController class
      klass = "#{controller.capitalize}Controller" unless controller.nil?
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
    controller.params[:uri] = params
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
      controller.send(method) unless method.nil?
    rescue Exception => e
      trace :error, "ERROR: " + e.message
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
    end

    # the controller work has finished
    controller.cleanup

    return resp_status, resp_content, resp_content_type, resp_cookie
  end

  # returns an hash containing the parameters passed to a POST or PUT request
  def http_parse_parameters(content)
    parsed = {}

    # sanity check
    return parsed if content.nil?

    # split the parameters
    params = content.split('&')
    params.each do |p|
      key, value = p.split('=')
      parsed[key.to_sym] = value
    end

    return parsed
  end

end #Parser

end #Collector::
end #RCS::