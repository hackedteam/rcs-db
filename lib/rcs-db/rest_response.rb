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

  def self.stream_file(filename, callback=nil)
    return RESTFileStream.new(filename, callback)
  end

  def self.stream_grid(grid_io, callback=nil)
    return RESTGridStream.new(grid_io, callback)
  end
  
  attr_accessor :status, :content, :content_type, :cookie
  
  def initialize(status, content = '', opts = {}, callback=proc{})
    @status = status
    @status = RCS::DB::RESTController::STATUS_SERVER_ERROR if @status.nil? or @status.class != Fixnum
    
    @content = content
    @content_type = opts[:content_type]
    @content_type ||= 'application/json'
    
    @cookie ||= opts[:cookie]

    @callback=callback
  end
  
  def keep_alive?(connection)
    http_headers = connection.instance_variable_get :@http_headers
    http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']}
  end
  
  #
  # BEWARE: for any reason this method should raise an exception!
  # An exception raised here WILL NOT be cough, resulting in a crash.
  #
  def prepare_response(connection, request)

    @request = request
    @connection = connection
    @response = EM::DelegatedHttpResponse.new @connection
    
    @response.status = @status
    @response.status_string = ::Net::HTTPResponse::CODE_TO_OBJ["#{@response.status}"].name.gsub(/Net::HTTP/, '')
    
    begin
      @response.content = (@content_type == 'application/json') ? @content.to_json : @content
    rescue Exception
      @response.status = STATUS_SERVER_ERROR
      @response.content = 'JSON_SERIALIZATION_ERROR'
    end
    
    @response.headers['Content-Type'] = @content_type
    @response.headers['Set-Cookie'] = @cookie unless @cookie.nil?
    
    if keep_alive? connection
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end
    
    self
  end

  def content
    @response.content
  end

  def headers
    @response.headers
  end

  def send_response
    @response.send_response
    @callback
  end

end # RESTResponse

class RESTFileStream
  
  def initialize(filename, callback=proc{})
    @filename = filename
    @callback = callback
  end

  def keep_alive?(connection)
    http_headers = connection.instance_variable_get :@http_headers
    http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']}
  end

  def prepare_response(connection, request)

    @request = request
    @connection = connection
    @response = EM::DelegatedHttpResponse.new @connection

    @response.headers["Content-length"] = File.size @filename

    # TODO: turbo zozza per content-length
    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    
    @response.headers["Content-Type"] = RCS::MimeType.get @filename
    
    if keep_alive? connection
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end

    self
  end

  def content
    @response.content
  end

  def headers
    @response.headers
  end
  
  def send_response
    @response.send_headers
    streamer = EventMachine::FileStreamer.new(@connection, @filename, :http_chunks => false )
    streamer.callback { @callback.call }
  end
end # RESTFileStream

class RESTGridStream
  def initialize(id, collection, callback=proc{})
    @id = id
    @collection = collection
    @grid_io = GridFS.get(id, collection)
    @callback = callback
  end
  
  def keep_alive?(connection)
    http_headers = connection.instance_variable_get :@http_headers
    http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']}
  end
  
  def prepare_response(connection, request)

    @request = request
    @connection = connection
    @response = EM::DelegatedHttpResponse.new @connection
    
    @response.headers["Content-length"] = @grid_io.file_length
    
    # TODO: turbo zozza per content-length
    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    
    @response.headers["Content-Type"] = @grid_io.content_type
    
    if keep_alive? connection
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end
    
    self
  end
  
  def send_response
    @response.send_headers
    streamer = EventMachine::GridStreamer.new(@connection, @grid_io, :http_chunks => false)
    streamer.callback { @callback.call }
  end
end # RESTGridStream

end # ::DB
end # ::RCS
