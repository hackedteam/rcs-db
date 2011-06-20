#
#  HTTP requests parsing module
#

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
  
  def parse_uri(uri)
    root, controller_name, *rest = uri.split('/')
    controller = "#{controller_name.capitalize}Controller"
    params = {:_default => rest}
    return controller, params
  end
  
  def parse_query_parameters(query)
    return {} if query.nil?
    return CGI::parse(query)
  end
  
  def parse_json_content(content)
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
  
  def guid_from_cookie(cookie)
    # this will match our GUID session cookie
    re = '.*?(session=)([A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12})'
    m = Regexp.new(re, Regexp::IGNORECASE).match(cookie)
    return m[2] unless m.nil?
    return nil
  end
  
  def prepare_request(method, uri, query, cookie, content)
    controller, params = parse_uri uri
    params.merge! parse_query_parameters query
    params.merge! parse_json_content content
    
    request = {
        controller: controller,
        method: method,
        params: params,
        cookie: guid_from_cookie(cookie)
    }
  end
  
  def flex_override_action(controller, request)
    action = request[:params][:_default].first
    if action.first.nil? or false == controller.respond_to?(action)
      return RCS::DB::RESTController.map_method_to_action(request[:method], request[:params][:_default].empty?)
    end
    return request[:params][:_default].shift.to_sym
  end
end #Parser

end #DB::
end #RCS::