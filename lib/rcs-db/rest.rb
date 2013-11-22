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
require 'base64'
require 'rcs-common/rest'

module RCS
module DB

class NotAuthorized < StandardError
  def initialize(actual, required)
    @message = "required priv is #{required} you have #{actual}"
    super @message
  end
end

class BasicAuthRequired < StandardError
  def initialize
    @message = "basic auth required for this uri"
    super @message
  end
end

class RESTController
  include RCS::Tracer
  include RCS::Common::Rest

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

  def redirect(message='', opts={}, callback=nil)
    opts[:content_type] = 'text/html'
    RESTResponse.new(STATUS_REDIRECT, message, opts, callback)
  end

  def not_authorized(message='', callback=nil)
    RESTResponse.new(STATUS_NOT_AUTHORIZED, message, {}, callback)
  end

  def auth_required(message='', callback=nil)
    RESTResponse.new(STATUS_AUTH_REQUIRED, message, {}, callback)
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

  def self.require_license(*args)
    options = args.pop
    license = options[:license] || raise("Missing license option")
    self.send(:define_method, :require_license_methods) do
      {methods: args, license: license}
    end
  end

  def request=(request)
    @request = request
    identify_action
  end
  
  def valid_session?
    @session = RESTController.sessionmanager.get(@request[:cookie])

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

  def valid_license?
    if respond_to?(:require_license_methods) and require_license_methods[:methods].include?(@request[:action])
      LicenseManager.instance.check(require_license_methods[:license])
    else
      true
    end
  end

  def act!
    begin
      # check we have a valid session and an action
      return not_authorized('INVALID_LICENSE') unless valid_license?
      return not_authorized('INVALID_COOKIE') unless valid_session?
      return server_error('NULL_ACTION') if @request[:action].nil?

      # make a copy of the params, handy for access and mongoid queries
      # consolidate URI parameters
      @params = @request[:params].clone unless @request[:params].nil?
      @params ||= {}
      unless @params.has_key? '_id'
        @params['_id'] = @request[:uri_params].first unless @request[:uri_params].first.nil?
      end

      return not_authorized("INVALID_ACTION") if private_methods.include?(@request[:action])

      # Execute the action
      response = __send__(@request[:action])

      return server_error('CONTROLLER_ERROR') if response.nil?
      return response
    rescue NotAuthorized => e
      trace :error, "[#{@request[:peer]}] Request not authorized: #{e.message}"
      return not_authorized(e.message)
    rescue BasicAuthRequired => e
      trace :error, "[#{@request[:peer]}] Request not authorized: #{e.message}"
      return auth_required(e.message)
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
        return (no_params ? :index : :show)
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
    if (levels & @session[:level]).empty?
      trace :warn, "Trying to access #{@request[:uri]} with #{@session[:level]}"
      raise NotAuthorized.new(@session[:level], levels)
    end
  end

  def require_basic_auth

    # check if the headers contains the authentication
    auth = @request[:headers][:authorization]
    # no header
    raise BasicAuthRequired.new if auth.nil?

    type, encoded = auth.split(' ')

    # check for bad requests
    raise BasicAuthRequired.new if type.downcase != 'basic'

    # parse the auth record
    username, password = Base64.decode64(encoded).split(':')

    user = User.where(name: username).first

    raise BasicAuthRequired.new if user.nil? or not user.enabled

    raise BasicAuthRequired.new unless user.verify_password(password)

    trace :info, "Auth granted for user #{username} to #{@request[:uri]}"
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

  def server?
    return @session[:level].include? :server
  end

  def mongoid_query(&block)
    begin
      start = Time.now
      ret = yield
      @request[:time][:moingoid] = Time.now - start
      return ret
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
    rescue BlacklistError => e
      trace :error, "Blacklist: #{e.message}"
      return conflict(e.message)
    rescue Exception => e
      trace :error, e.message
      trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
      return server_error(e.message)
    end
  end

end # RESTController

class InvalidController < RESTController
  def act!
    trace :error, "[#{@request[:peer]}] Invalid controller invoked: #{@request[:controller]}/#{@request[:action]}. Replied 404."
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
