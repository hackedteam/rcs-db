#
# The REST interface for all the rest Objects
#

# relatives
require_relative 'audit'
require_relative 'rest_response'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'bson'
require 'json'


module EventMachine
  class FileStreamer
    # on windows the stream_without_mapping has HUGE problems
    # we monkey patch the class to force it to ALWAYS stream a file
    # the mapping threshold is responsible to choose the behavior
    if RUBY_PLATFORM =~ /mingw/
      MappingThreshold = 0
    end
  end
end

module RCS
module DB

class NotAuthorized < StandardError
  def initialize(actual, required)
    @message = "required priv is #{required} you have #{actual}"
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
  attr_reader :session, :request
  
  @controllers = {}

  def ok(*args)
    RESTResponse.new STATUS_OK, *args
  end

  #def generic(*args)
  #  return RESTResponse.new *args
  #end

  def not_found(message='', callback=nil)
    RESTResponse.new(STATUS_NOT_FOUND, message, {}, callback)
  end

  def not_authorized(message='', callback=nil)
    RESTResponse.new(STATUS_NOT_AUTHORIZED, message, {}, callback)
  end

  def conflict(message='', callback=nil)
    RESTResponse.new(STATUS_CONFLICT, message, {}, callback)
  end

  def bad_request(message='', callback=nil)
    RESTResponse.new(STATUS_BAD_REQUEST, message, {}, callback)
  end

  def server_error(message='', callback=nil)
    RESTResponse.new(STATUS_SERVER_ERROR, message, {}, callback)
  end
  
  def stream_file(filename, callback=nil)
    begin
      RESTFileStream.new(filename, callback)
    rescue Exception => e
      not_found(e.message)
    end
  end
  
  def stream_grid(id, collection=nil, callback=proc{})
    begin
      RESTGridStream.new(id, collection, callback)
    rescue Exception => e
      not_found(e.message)
    end
  end
  
  def self.register(klass)
    @controllers[klass.to_s] = RCS::DB.const_get(klass) if klass.to_s.end_with? "Controller"
  end
  
  def self.sessionmanager
    @session_manager || SessionManager.instance
  end

  def self.get(request)
    name = request[:controller]
    begin
      controller = @controllers["#{name}"].new
    rescue Exception => e
      controller = InvalidController.new
    end
    
    controller.request = request
    controller
  end

  def self.bypass_auth(methods)
    self.send(:define_method, :bypass_auth_methods) do
      methods
    end
  end

  def request=(request)
    @request = request
    identify_action
  end
  
  def valid_session?
    @session = RESTController.sessionmanager.get(@request[:cookie])
    unless @session.nil?
      RESTController.sessionmanager.update(@request[:cookie])
      #trace :debug, "Refreshing session for #{@session[:user][:name]}"
    end
    
    # methods without authentication
    # class XXXXController < RESTController
    #
    #   bypass_auth [:method]
    #
    #   def method
    #     ...
    return true if self.respond_to?(:bypass_auth_methods) and bypass_auth_methods.include? @request[:action]

    # without a valid session you cannot operate
    return false if @session.nil?

    return true
  end
  
  def identify_action
    action = @request[:uri_params].first
    if not action.nil? and respond_to?(action)
      # use the default http method as action
      @request[:action] = @request[:uri_params].shift.to_sym
    else
      @request[:action] = map_method_to_action(@request[:method], @request[:uri_params].empty?)
    end
  end

  def act!
    begin
      # check we have a valid session and an action
      return not_authorized('INVALID_COOKIE') unless valid_session?
      return server_error('NULL_ACTION') if @request[:action].nil?

      # make a copy of the params, handy for access and mongoid queries
      # consolidate URI parameters
      @params = @request[:params].clone unless @request[:params].nil?
      @params ||= {}
      unless @params.has_key? '_id'
        @params['_id'] = @request[:uri_params].first unless @request[:uri_params].first.nil?
      end

      # GO!
      response = send(@request[:action])

      return server_error('CONTROLLER_ERROR') if response.nil?
      return response
    rescue NotAuthorized => e
      trace :error, "[#{@request[:peer]}] Request not authorized: #{e.message}"
      return not_authorized(e.message)
    rescue Exception => e
      trace :error, "Server error: #{e.message}"
      trace :fatal, "Backtrace   : #{e.backtrace}"
      return server_error(e.message)
    end
  end
  
  def cleanup
    # hook method if you need to perform some cleanup operation
  end
  
  def map_method_to_action(method, no_params)
    case method
      when 'GET'
        return (no_params == true ? :index : :show)
      when 'POST'
        return :create
      when 'PUT'
        return :update
      when 'DELETE'
        return :destroy
    end
  end
  
  # macro for auth level check
  def require_auth_level(*levels)
    # TODO: checking auth level should be done by SessionManager, refactor

    if (levels & @session[:level]).empty?
      trace :warn, "Trying to access #{@request[:uri]} with #{@session[:level]}"
      raise NotAuthorized.new(@session[:level], levels)
    end
  end

  def admin?
    return @session[:level].include? :admin
  end

  def system?
    return @session[:level].include? :sys
  end

  def tech?
    return @session[:level].include? :tech
  end

  def view?
    return @session[:level].include? :view
  end
  
  # TODO: mongoid_query doesn't belong here
  def mongoid_query(&block)
    begin
      yield
    rescue Mongo::ConnectionFailure =>  e
      trace :error, "Connection to database lost, retrying in 5 seconds..."
      sleep 5
      retry if attempt ||= 0 and attempt += 1 and attempt < 2
    rescue Mongoid::Errors::DocumentNotFound => e
      trace :error, "Document not found => #{e.message}"
      return not_found(e.message)
    rescue Mongoid::Errors::InvalidOptions => e
      trace :error, "Invalid parameter => #{e.message}"
      return bad_request(e.message)
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return bad_request(e.message)
    rescue Exception => e
      trace :error, e.message
      trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
      return server_error(e.message)
    end
  end

end # RESTController

class InvalidController < RESTController
  def act!
    trace :error, "Invalid controller invoked: #{@request[:controller]}/#{@request[:action]}. Replied 404."
    not_found('File not found')
  end
end

# require all the controllers
Dir[File.dirname(__FILE__) + '/rest/*.rb'].each do |file|
  require file
end

# register all controllers into RESTController
RCS::DB.constants.keep_if{|x| x.to_s.end_with? 'Controller'}.each do |klass|
  RCS::DB::RESTController.register klass
end

end #DB::
end #RCS::
