# from RCS::Common
require 'rcs-common/trace'

require 'net/http'
require 'rbconfig'

module RCS
module Worker

class RESTResponse
  include RCS::Tracer

  attr_accessor :status, :content, :content_type, :cookie
  
  def initialize(status, content = '', opts = {}, callback=proc{})
    @status = status
    @status = RCS::DB::RESTController::STATUS_SERVER_ERROR if @status.nil? or @status.class != Fixnum
    
    @content = content
    @content_type = opts[:content_type]
    @content_type ||= 'application/json'

    @cookie ||= opts[:cookie]
    
    @callback = callback
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

end # ::Worker
end # ::RCS
