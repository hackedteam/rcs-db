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
  attr_accessor :params

  def init(http_headers, req_method, req_uri, req_cookie, req_content, req_peer)

    # cookie parsing
    # we extract the session cookie from the cookies, proxies or browsers can
    # add cookies that has nothing to do with our session

    # this will match our GUID session cookie
    re = '.*?(session=)([A-Z0-9]{8}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{12})'

    # match on the cookies and return the parsed GUID (the third match of the regexp)
    m = Regexp.new(re, Regexp::IGNORECASE).match(req_cookie)
    cookie = m[2] unless m.nil?

    @http_headers = http_headers
    @req_method = req_method
    @req_uri = req_uri
    @req_cookie = req_cookie || ''
    @session_cookie = cookie
    @req_content = req_content
    @req_peer = req_peer
    # the parsed http parameters (from uri and from content)
    @params = {}
    
    # if we are at auth/login, permit always
    root, controller_name, *params = req_uri.split('/')
    return true if controller_name.capitalize.eql? 'Auth' and params.first.eql? 'login'
    
    # no cookie, no methods
    return false if cookie.nil?
    
    # we have a cookie, check if it's valid
    if SessionManager.instance.check(cookie) then
      @session = SessionManager.instance.get(cookie)
      return true
    end
    
    trace :warn, "[#{@peer}][#{cookie}] Invalid cookie"
    return false
  end
  
  def cleanup
    # hook method if you need to perform some cleanup operation
  end
  
  def self.get_controller(name)
    return nil if name.nil?
    begin
      controller = eval("#{name.capitalize}Controller").new
      return controller
    rescue
      return nil
    end
  end
  
  def self.not_found
    return RESTResponse.new(STATUS_NOT_FOUND)
  end
  
  def self.not_authorized message=''
    return RESTResponse.new(STATUS_NOT_AUTHORIZED, message)
  end

  def self.conflict message = ''
    return RESTResponse.new(STATUS_CONFLICT, message)
  end

  def self.server_error message = ''
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

  # macro for auth level check
  def require_auth_level(*levels)
    raise NotAuthorized.new(@session[:level], levels) if (levels & @session[:level]).empty?
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
    
    @content_type = opts[:content_type]
    @content_type ||= 'application/json'
    
    @cookie = opts[:cookie]
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
