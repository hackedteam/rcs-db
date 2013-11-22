#
# response handling classes
#

require_relative 'em_streamer'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/rest'

require 'net/http'
require 'stringio'
require 'json'
require 'zlib'

module RCS
module DB

class RESTResponse
  include RCS::Tracer
  include RCS::Common::Rest

  attr_accessor :status, :content, :content_type, :cookie

  def initialize(status, content = '', opts = {}, callback=proc{})
    @status = status
    @status = STATUS_SERVER_ERROR if @status.nil? or @status.class != Fixnum
    
    @content = content
    @content_type = opts[:content_type]
    @content_type ||= 'application/json'
    @location ||= opts[:location]
    @cookie ||= opts[:cookie]

    @opts = opts

    @callback = callback

    @response = nil
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
    @cache_json ||= Config.instance.global['JSON_CACHE']

    begin
      start = Time.now

      final_content = if @content_type == 'application/json'
        @cache_json ? Cache::Manager.instance.process(@content, {uri: @request[:uri]}) : @content.to_json
      else
        @content
      end

      @request[:time][:json] = Time.now - start

      if @opts[:gzip]
        compressed = StringIO.open("", 'w')
        gzip = Zlib::GzipWriter.new(compressed)
        gzip.write final_content
        gzip.close
        @response.content = compressed.string
      else
        @response.content = final_content
      end

    rescue Exception => e
      @response.status = STATUS_SERVER_ERROR
      @response.content = 'JSON_SERIALIZATION_ERROR'
      trace :error, e.message
      trace :error, "CONTENT: #{@content}"
      trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
    end
    
    @response.headers['Content-Type'] = @content_type
    @response.headers['Set-Cookie'] = @cookie unless @cookie.nil?

    @response.headers['WWW-Authenticate'] = "Basic realm=\"Secure Area\"" if @response.status == STATUS_AUTH_REQUIRED

    # used for redirects
    @response.headers['Location'] = @location unless @location.nil?

    if request[:headers][:connection] && request[:headers][:connection].downcase == 'keep-alive'
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end

    @response.headers['Content-Encoding'] = 'gzip' if @opts[:gzip]
    
    self
  end

  def size
    fail "response still not prepared" if @response.nil?
    return 0 if @response.content.nil?
    @response.content.bytesize
  end

  def content
    fail "response still not prepared" if @response.nil?
    @response.content
  end

  def headers
    fail "response still not prepared" if @response.nil?
    @response.headers
  end

  def send_response
    fail "response still not prepared" if @response.nil?
    @response.send_response
    @callback unless @callback.nil?
    trace :debug, "[#{@request[:peer]}] REP: [#{@request[:method]}] #{@request[:uri]} #{@request[:query]} (#{Time.now - @request[:time][:start]})" if @request and Config.instance.global['PERF']
  end

end # RESTResponse

class RESTFileStream
  include RCS::Tracer
  
  def initialize(filename, callback=proc{})
    @filename = filename
    @callback = callback
    @response = nil
  end

  def prepare_response(connection, request)

    @request = request
    @connection = connection
    @response = EM::DelegatedHttpResponse.new @connection

    @response.status = 200
    @response.status_string = ::Net::HTTPResponse::CODE_TO_OBJ["#{@response.status}"].name.gsub(/Net::HTTP/, '')

    @response.headers["Content-length"] = File.size @filename

    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    
    @response.headers["Content-Type"] = RCS::MimeType.get @filename

    if request[:headers][:connection] && request[:headers][:connection].downcase == 'keep-alive'
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end

    self
  end

  def size
    fail "response still not prepared" if @response.nil?
    @response.headers["Content-length"]
  end

  def content
    fail "response still not prepared" if @response.nil?
    @response.content
  end

  def headers
    fail "response still not prepared" if @response.nil?
    @response.headers
  end
  
  def send_response
    fail "response still not prepared" if @response.nil?
    @response.send_headers
    streamer = EM::FilesystemStreamer.new(@connection, @filename, :http_chunks => false )
    streamer.callback do
      @callback.call unless @callback.nil?
      trace :debug, "[#{@request[:peer]}] REP: [#{@request[:method]}] #{@request[:uri]} #{@request[:query]} (#{Time.now - @request[:time][:start]})" if Config.instance.global['PERF']
    end
  end
end # RESTFileStream

class RESTGridStream
  include RCS::Tracer
  
  def initialize(id, collection, callback)
    @grid_io = GridFS.get id, collection
    fail "grid object not found" if @grid_io.nil?
    
    @callback = callback
    @response = nil
  end

  def prepare_response(connection, request)
    
    @request = request
    @connection = connection
    @response = EM::DelegatedHttpResponse.new @connection
    
    @response.headers["Content-length"] = @grid_io.file_length
    
    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    
    @response.headers["Content-Type"] = @grid_io.content_type
    
    if request[:headers][:connection] && request[:headers][:connection].downcase == 'keep-alive'
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      @response.keep_connection_open true
      @response.headers['Connection'] = 'keep-alive'
    else
      @response.headers['Connection'] = 'close'
    end
    
    self
  end

  def size
    fail "response still not prepared" if @response.nil?
    @response.headers["Content-length"]
  end

  def content
    fail "response still not prepared" if @response.nil?
    @response.content
  end

  def headers
    fail "response still not prepared" if @response.nil?
    @response.headers
  end
  
  def send_response
    fail "response still not prepared" if @response.nil?
    @response.send_headers
    streamer = EM::GridStreamer.new(@connection, @grid_io, :http_chunks => false)
    streamer.callback do
      @callback.call unless @callback.nil?
      trace :debug, "[#{@request[:peer]}] REP: [#{@request[:method]}] #{@request[:uri]} #{@request[:query]} (#{Time.now - @request[:time][:start]})" if Config.instance.global['PERF']
    end
  end
end # RESTGridStream

end # ::DB
end # ::RCS
