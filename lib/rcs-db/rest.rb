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

module RCS
module DB

class NotAuthorized < StandardError
  def initialize(actual, required)
    @message = "#{actual} not in #{required}"
    super @message
  end
end

class RESTController
  include RCS::Tracer
  
  # the parameters passed on the REST request
  attr_reader :session, :request
  
  def self.sessionmanager
    @session_manager || SessionManager.instance
  end
  
  def self.reply
    @response_class || RESTResponse
  end
  
  def self.get(request)
    name = request[:controller]
    return nil if name.nil?
    begin
      controller = eval("#{name}").new
    rescue NameError => e
      controller = InvalidController.new
    end
      controller.request = request
      controller
  end
  
  def request=(request)
    @request = request
    identify_action
  end
  
  def valid_session?
    @session = RESTController.sessionmanager.get(@request[:cookie])
    RESTController.sessionmanager.update(@request[:cookie]) unless session.nil?
    
    return false if @session.nil? and not logging_in?
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
  
  def logging_in?
    # TODO: each method should define if it's able bypass authentication
    # something like
    # class AuthController < RESTController
    #   def login
    #     bypass_authentication true
    #     ...
    (@request[:controller].eql? 'AuthController' and [:login, :reset].include? @request[:action])
  end
  
  def act!
    # check we have a valid session and an action
    return RESTController.reply.not_authorized('INVALID_COOKIE') unless valid_session?
    return RESTController.reply.server_error('NULL_ACTION') if @request[:action].nil?
    
    # make a copy of the params, handy for access and mongoid queries
    # consolidate URI parameters
    @params = @request[:params].clone unless @request[:params].nil?
    @params ||= {}
    unless @params.has_key? '_id'
      @params['_id'] = @request[:uri_params].first unless @request[:uri_params].first.nil?
    end
    
    # GO!
    response = send(@request[:action])
    
    return RESTController.reply.server_error('CONTROLLER_ERROR') if response.nil?
    return response
  rescue NotAuthorized => e
    trace :error, "[#{@request[:peer]}] Request not authorized: #{e.message}"
    return RESTController.reply.not_authorized(e.message)
  rescue Exception => e
    trace :error, "Server error: #{e.message}"
    trace :fatal, "Backtrace   : #{e.backtrace}"
    return RESTController.reply.server_error(e.message)
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
    raise NotAuthorized.new(@session[:level], levels) if (levels & @session[:level]).empty?
  end
  
  # TODO: mongoid_query doesn't belong here
  def mongoid_query(&block)
    begin
      yield
    rescue Mongoid::Errors::DocumentNotFound => e
      trace :error, "Document not found => #{e.message}"
      return RESTController.reply.not_found(e.message)
    rescue Mongoid::Errors::InvalidOptions => e
      trace :error, "Invalid parameter => #{e.message}"
      return RESTController.reply.bad_request(e.message)
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return RESTController.reply.bad_request(e.message)
    rescue Exception => e
      trace :error, e.message
      trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
      return RESTController.reply.not_found
    end
  end

end # RESTController

class InvalidController < RESTController
  def act!
    trace :error, "Invalid controller invoked: #{@request[:controller]}/#{@request[:action]}. Replied 404."
    RESTController.reply.not_found
  end
end

end #DB::
end #RCS::
