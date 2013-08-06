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

require 'webrick'

module RCS
module DB

module Parser
  include RCS::Tracer
  include WEBrick::HTTPUtils
  
  CRLF = "\x0d\x0a"

  def parse_uri(uri)
    root, controller_name, *rest = uri.split('/')
    controller = "#{controller_name.capitalize}Controller" unless controller_name.nil?
    return controller, rest
  end
  
  def parse_query_parameters(query)
    return {} if query.nil?
    parsed = CGI::parse(query)
    # if value is an array with a lone value, assign direct value to hash key
    parsed.each_pair { |k,v| parsed[k] = v.first if v.class == Array and v.size == 1 }
    return parsed
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

  def parse_multipart_content(content, content_type)
    # extract the boundary from the content type:
    # e.g. multipart/form-data; boundary=530565
    boundary = content_type.split('boundary=')[1]

    begin
      # this function is from WEBrick::HTTPUtils module
      return parse_form_data(content, boundary)
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

  # we handle the following types of requests:
  # /<controller>
  # /<controller>/<method>
  # /<controller>/<method>/<id>
  #
  # - any CGI style query ("?q=pippo,pluto&filter=all") will be parsed and passed as parameters
  # - JSON encoded POST content ("{"q": ["pippo", "pluto"], "filter": "all"}") will be treated as a CGI query
  # - multipart POST will be parsed correctly and :content contains all the parts
  #
  def prepare_request(method, uri, query, content, http, peer)
    controller, uri_params = parse_uri(uri)

    params = Hash.new
    params.merge! parse_query_parameters(query)

    request = Hash.new
    request[:controller] = controller
    request[:method] = method
    request[:query] = query
    request[:uri] = uri
    request[:uri_params] = uri_params
    request[:cookie] = guid_from_cookie(http[:cookie])
    # if not content_type is provided, default to urlencoded
    request[:content_type] = http[:content_type] || 'application/x-www-form-urlencoded'

    if request[:content_type]['multipart/form-data']
      request[:content] = parse_multipart_content(content, http[:content_type])
      request[:content][:type] = 'multipart'
    elsif request[:content_type]['ruby/marshal']
      object = Marshal.load(content) rescue nil
      request[:content] = object
      request[:content][:type] = 'object'
      params.merge!(object.stringify_keys) if object.kind_of?(Hash)
    else
      json_content = parse_json_content(content)
      request[:content] = {'content' => content}

      if json_content.blank?
        request[:content][:type] = 'binary'
      else
        params.merge!(json_content)
        request[:content][:type] = 'json'
      end
    end

    request[:params] = params
    request[:headers] = http
    request[:peer] = peer
    request
  end
end # Parser

end #DB::
end #RCS::