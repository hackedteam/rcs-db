#
# The REST interface for all the rest Objects
#

# relatives
require_relative 'sessions'
require_relative 'audit'
require_relative 'config'
require_relative 'audit'
require_relative 'em_streamer'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'bson'
require 'json'

module RCS
module DB

class NotAuthorized < StandardError
  def initialize(actual, required)
    @message = "#{required} not in #{actual}"
    super @message
  end
end

class RESTController
  include RCS::Tracer
  
  STATUS_OK = 200
  STATUS_BAD_REQUEST = 400
  STATUS_NOT_FOUND = 404
  STATUS_NOT_AUTHORIZED = 403
  STATUS_CONFLICT = 409
  STATUS_SERVER_ERROR = 500
  
  # the parameters passed on the REST request
  attr_reader :params, :request, :headers
  
  def guid_from_cookie(cookie)
    # this will match our GUID session cookie
    re = '.*?(session=)([A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12})'
    m = Regexp.new(re, Regexp::IGNORECASE).match(cookie)
    return m[2] unless m.nil?
    return nil
  end
  
  def session_cookie
    @http_request[:session_id]
  end
  
  def controller_name
    self.class.to_s.split(':')[4]
  end
  
  def init(http_headers, request, params)
    
    trace :debug, "RAW PARAMS: #{params}"
    
    @headers = http_headers
    @request = request
    
    #@opts = request
    @req_method = request[:method]
    @req_uri = request[:uri]
    @req_cookie = request[:cookie] || ''
    @req_content = request[:content]
    @req_peer = request[:peer]
    
    # determine action
    @rest = {}
    @rest[:action] = params.shift if not params.first.nil? and respond_to?(params.first)
    if @rest[:action].nil?
      case request[:method]
        when 'GET'
          method = (params.empty?) ? :index : :show
        when 'POST'
          method = :create
        when 'PUT'
          method = :update
        when 'DELETE'
          method = :destroy
      end
      @rest[:action] = method
    end
    trace :debug, "REST ACTION: #{@rest[:action]}"
    
    # save the params in the controller object
    # the parsed http parameters (from uri and from content)
    @params = {}
    @params[controller_name.downcase] = params.first unless params.first.nil?
    @params.merge!(CGI::parse(@request[:query])) unless @request[:query].nil?
    @params.merge! parse_json_content(@request[:content]) unless @request[:content].nil?

    trace :debug, "REST PARAMS: #{@params}"
    
    # we extract the session id from the cookies
    @request[:session_id] = guid_from_cookie(@request[:cookie])
    
    trace :debug, "SESSION ID : #{@request[:session_id]}"
  end
  
  def valid_request?
    # if we are at auth/login, permit always
    return true if logging_in?
    
    # no cookie, no methods
    return false if @request[:session_id].nil?
    
    # we have a cookie, check if it's valid
    @session = SessionManager.instance.get(@request[:session_id])
    return true unless @session.nil?
    
    # no cookie, no party!
    trace :warn, "[#{@request[:peer]}][#{@request[:session_id]}] Invalid cookie"
    return false
  end
  
  def act!
    send(@rest[:action])
  end

  def logging_in?
    self.class == RCS::DB::AuthController and @rest[:action].eql? 'login'
  end
  
  def cleanup
    # hook method if you need to perform some cleanup operation
  end
  
  def self.get_controller(name, http_headers, request, params)
    return nil if name.nil?
    begin
      controller = eval("#{name.capitalize}Controller").new
      controller.init(http_headers, request, params) unless controller.nil?
      return controller
    rescue Exception => e
      puts e.message
      return nil
    end
  end
  
  def self.not_found
    return RESTResponse.new(STATUS_NOT_FOUND)
  end
  
  def self.not_authorized message
    message = '' unless message.nil?
    return RESTResponse.new(STATUS_NOT_AUTHORIZED, message)
  end
  
  def self.conflict message
    message = '' unless message.nil?
    return RESTResponse.new(STATUS_CONFLICT, message)
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

  # macro for auth level check
  def require_auth_level(*levels)
    raise NotAuthorized.new(@session[:level], levels) if (levels & @session[:level]).empty?
  end

  # returns the JSON parsed object containing the parameters passed to a POST or PUT request
  def parse_json_content(content)
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

  def mongoid_query(&block)
    begin
      yield
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return STATUS_BAD_REQUEST, *json_reply(e.message)
    rescue Exception => e
      trace :error, e.message
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      return STATUS_NOT_FOUND, *json_reply(e.message)
    end
  end

  def create
    # POST /object
  end

  def index
    # GET /object
  end

  def show
    # GET /object/id
  end

  def update
    # PUT /object/id
  end

  def destroy
    # DELETE /object/id
  end

  # everything else is a method name
  # for example:
  # GET /object/method
  # will invoke :method on the ObjectController instance

end

end #DB::
end #RCS::

# require all the controllers
Dir[File.dirname(__FILE__) + '/rest/*.rb'].each do |file|
  require file
end

class RESTResponse
  include RCS::Tracer
  
  attr_accessor :status, :content, :content_type, :cookie
  
  def initialize(status, content = '', opts = {})
    @status = status
    @content = content
    
    @content_type = 'application/json'
    @content_type = opts[:content_type] if opts.has_key? :content_type
    
    @cookie = nil
    @cookie = opts[:cookie] if opts.has_key? :cookie
  end
  
  def send_response(connection)

    resp = EM::DelegatedHttpResponse.new connection
    @status = RCS::DB::RESTController::STATUS_SERVER_ERROR if @status.nil? or @status.class != Fixnum

    resp.status = @status
    
    resp.status_string = Net::HTTPResponse::CODE_TO_OBJ["#{resp.status}"].name.gsub(/Net::HTTP/, '')

    begin
      resp.content = (content_type == 'application/json') ? @content.to_json : @content
    rescue
      trace :error, "Cannot parse json reply: #{@content}"
      resp.content = "JSON_SERIALIZATION_ERROR".to_json
    end
    
    resp.headers['Content-Type'] = @content_type
    resp.headers['Set-Cookie'] = @cookie unless @cookie.nil?

    http_headers = connection.instance_variable_get :@http_headers
    if http_headers.split("\x00").index {|h| h['Connection: keep-alive'] || h['Connection: Keep-Alive']} then
      # keep the connection open to allow multiple requests on the same connection
      # this will increase the speed of sync since it decrease the latency on the net
      resp.keep_connection_open true
      resp.headers['Connection'] = 'keep-alive'
    else
      resp.headers['Connection'] = 'close'
    end

    resp.send_response
  end
end

class RESTGridStream
  def initialize(grid_io)
    @grid_io = grid_io
  end

  def send_response(connection)
    response = EM::DelegatedHttpGridResponse.new connection, @grid_io
    response.send_headers
    response.send_body
  end
end

class RESTFileStream
  def initialize(filename)
    @filename = filename
  end

  def send_response(connection)
    response = EM::DelegatedHttpFileResponse.new connection, @filename
    response.send_headers
    response.send_body
  end
end
