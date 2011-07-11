# from RCS::Common
require 'rcs-common/trace'

require 'net/http'
require_relative 'em_streamer'

module RCS
module DB

class RESTResponse
  include RCS::Tracer

  STATUS_OK = 200
  STATUS_BAD_REQUEST = 400
  STATUS_NOT_FOUND = 404
  STATUS_NOT_AUTHORIZED = 403
  STATUS_CONFLICT = 409
  STATUS_SERVER_ERROR = 500

  def self.not_found(message=nil)
    message ||= ''
    return RESTResponse.new(STATUS_NOT_FOUND, message)
  end

  def self.not_authorized(message=nil)
    message ||= ''
    return RESTResponse.new(STATUS_NOT_AUTHORIZED, message)
  end

  def self.conflict(message=nil)
    message ||= ''
    return RESTResponse.new(STATUS_CONFLICT, message)
  end

  def self.bad_request(message=nil)
    message ||= ''
    return RESTResponse.new(STATUS_BAD_REQUEST, message)
  end

  def self.server_error(message=nil)
    message ||= ''
    return RESTResponse.new(STATUS_SERVER_ERROR, message)
  end

  # helper method for REST replies
  def self.ok(*args)
    return RESTResponse.new STATUS_OK, *args
  end

  def self.generic(*args)
    return RESTResponse.new *args
  end

  def self.stream_file(filename)
    return RESTFileStream.new(filename)
  end

  def self.stream_grid(grid_io)
    return RESTGridStream.new(grid_io)
  end
  
  attr_accessor :status, :content, :content_type, :cookie
  
  def initialize(status, content = '', opts = {})
    @status = status
    @status = RCS::DB::RESTController::STATUS_SERVER_ERROR if @status.nil? or @status.class != Fixnum
    
    @content = content
    @content_type = opts[:content_type]
    @content_type ||= 'application/json'
    
    @cookie ||= opts[:cookie]
  end
  
  def get_em_response(type, connection, opt=nil)
    case type
      when :http
        return EM::DelegatedHttpResponse.new connection
      when :grid
        return EM::DelegatedGridResponse.new connection, opt
      when :file
        return EM::DelegatedFileResponse.new connection, opt
    end
  end

  def keep_alive?(connection)
    http_headers = connection.instance_variable_get :@http_headers
    http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']}
  end
  
  #
  # BEWARE: for any reason this method should raise an exception!
  # An exception raised here WILL NOT be catched, resulting in a crash.
  #
  def prepare_response(connection)
    
    resp = get_em_response :http, connection
    
    resp.status = @status
    resp.status_string = ::Net::HTTPResponse::CODE_TO_OBJ["#{resp.status}"].name.gsub(/Net::HTTP/, '')

    begin
      resp.content = (content_type == 'application/json') ? @content.to_json : @content
    rescue Exception
      resp.status = STATUS_SERVER_ERROR
      resp.content = 'JSON_SERIALIZATION_ERROR'
    end
    
    resp.headers['Content-Type'] = @content_type
    resp.headers['Set-Cookie'] = @cookie unless @cookie.nil?
    
    if keep_alive? connection
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      resp.keep_connection_open true
      resp.headers['Connection'] = 'keep-alive'
    else
      resp.headers['Connection'] = 'close'
    end
    
    resp
  end

end # RESTResponse

class RESTGridStream
  def initialize(grid_io)
    @grid_io = grid_io
  end

  def prepare_response(connection)
    response = EM::DelegatedHttpGridResponse.new connection, @grid_io
    return response
  end
  
  def send_response
    response.send_headers
    response.send_body
  end
end # RESTGridStream

class RESTFileStream
  def initialize(filename)
    @filename = filename
  end
  
  def prepare_response(connection)
    response = EM::DelegatedHttpFileResponse.new connection, @filename
    return response
  end

  def send_response
    response.send_headers
    response.send_body
  end
end # RESTFileStream

end # ::DB
end # ::RCS
