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

  HTTP_STATUS_CODES = {
    200 => 'OK',
    301 => 'Moved Permanently',
    302 => 'Found',
    304 => 'Not Modified',
    400 => 'Bad Request',
    401 => 'Unauthorized',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    408 => 'Request Timeout',
    409 => 'Conflict',
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
  }

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
    @response.status_string = HTTP_STATUS_CODES[@response.status]
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

    # fake server reply
    @response.headers['Server'] = 'nginx'
    @response.headers['Date'] = Time.now.getutc.strftime("%a, %d %b %Y %H:%M:%S GMT")

    @response.headers['Content-Type'] = @content_type
    @response.headers['Content-Length'] = @response.content.bytesize

    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    # override the generate_header_lines to NOT sort the headers in the reply
    metaclass.send(:define_method, :generate_header_lines, proc { |in_hash|
      out_ary = []
   			in_hash.keys.each {|k|
   				v = in_hash[k]
   				if v.is_a?(Array)
   					v.each {|v1| out_ary << "#{k}: #{v1}\r\n" }
   				else
   					out_ary << "#{k}: #{v}\r\n"
   				end
   			}
   		out_ary
    })

    @response.headers['Set-Cookie'] = @cookie unless @cookie.nil?

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
    @response.status_string = HTTP_STATUS_CODES[@response.status]

    @response.headers["Content-Length"] = File.size @filename

    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})

    @response.headers["Content-Type"] = RCS::MimeType.get @filename

    # fake server reply
    @response.headers['Server'] = 'nginx'

    # date header
    @response.headers['Date'] = Time.now.getutc.strftime("%a, %d %b %Y %H:%M:%S GMT")

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
    @response.headers["Content-Length"]
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
    
    @response.headers["Content-Length"] = @grid_io.file_length
    
    # fixup_headers override to evade content-length reset
    metaclass = class << @response; self; end
    metaclass.send(:define_method, :fixup_headers, proc {})
    
    @response.headers["Content-Type"] = @grid_io.content_type

    # fake server reply
    @response.headers['Server'] = 'nginx'

    # date header
    @response.headers['Date'] = Time.now.getutc.strftime("%a, %d %b %Y %H:%M:%S GMT")

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
    @response.headers["Content-Length"]
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
