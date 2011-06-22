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
    @message = "#{required} not in #{actual}"
    super @message
  end
end

class RESTController
  include RCS::Tracer
  extend RCS::DB::RESTReplies
  
  # the parameters passed on the REST request
  attr_reader :session, :request
  
  def request=(request)
    @request = request
    identify_action
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
    (@request[:controller].eql? 'AuthController' and @request[:action].eql? :login)
  end
  
  def act!(session)
    @session = session
    
    # make a copy of the params, handy for access and mongoid queries
    @params = @request[:params].clone unless @request[:params].nil?
    
    # consolidate URI parameters
    @params ||= {}
    @params['_id'] = @request[:uri_params].first
    
    return RESTController.server_error('NULL_ACTION') if @request[:action].nil?
    send(@request[:action])
  end
  
  def cleanup
    # hook method if you need to perform some cleanup operation
  end
  
  def self.get(request)
    name = request[:controller]
    return nil if name.nil?
    begin
      controller = eval("#{name}").new
      controller.request = request
      return controller
    rescue NameError => e
      return nil
    end
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
    rescue BSON::InvalidObjectId => e
      trace :error, "Bad request #{e.class} => #{e.message}"
      return RESTController.bad_request(e.message)
    rescue Exception => e
      trace :error, e.message
      trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
      return RESTController.not_found
    end
  end
  
end # RESTController

end #DB::
end #RCS::
