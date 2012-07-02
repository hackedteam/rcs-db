#
# The REST interface for all the rest Objects
#

# relatives
require_relative 'rest_response'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'json'

module RCS
module Worker

module RESTController
  include RCS::Tracer
  
  STATUS_OK = 200
  STATUS_BAD_REQUEST = 400
  STATUS_NOT_FOUND = 404
  STATUS_NOT_AUTHORIZED = 403
  STATUS_CONFLICT = 409
  STATUS_SERVER_ERROR = 500
  
  # the parameters passed on the REST request
  attr_reader :request
  
  def self.extended(base)
    base.send :include, InstanceMethods
    base.send :include, RCS::Tracer

    base.instance_exec do
      # default values
      @controllers = {}
    end
  end
  
  module InstanceMethods

    # display a fake page in case someone is trying to connect to the collector
    # with a browser or something else
    def http_decoy_page
      # default decoy page
      page = "<html> <head>" +
             "<meta http-equiv=\"refresh\" content=\"0;url=http://www.google.com\">" +
             "</head> </html>"

      # custom decoy page
      file_path = Dir.pwd + "/config/decoy.html"
      page = File.read(file_path) if File.exist?(file_path)

      trace :info, "[#{@peer}] Decoy page displayed"

      return page
    end

    def ok(*args)
      RESTResponse.new STATUS_OK, *args
    end

    def decoy_page(callback=nil)
      ok(http_decoy_page, {content_type: 'text/html'}, callback)
    end

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

    def self.get(request)
      CollectorController
    end

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

    def act!
      # check we have a valid session and an action
      return decoy_page if @request[:action].nil?

      # make a copy of the params, handy for access and mongoid queries
      # consolidate URI parameters
      @params = @request[:params].clone unless @request[:params].nil?
      @params ||= {}
      unless @params.has_key? '_id'
        @params['_id'] = @request[:uri_params].first unless @request[:uri_params].first.nil?
      end

      # GO!
      response = send(@request[:action])

      return decoy_page if response.nil?
      return response
    rescue Exception => e
      trace :error, "Server error: #{e.message}"
      trace :fatal, "Backtrace   : #{e.backtrace}"
      return decoy_page
    end

    def cleanup
      # hook method if you need to perform some cleanup operation
    end

    def map_method_to_action(method, no_params)
      case method
        when 'GET'
          return :get
        when 'POST'
          return :post
        when 'PUT'
          return :put
        when 'DELETE'
          return :delete
      end
    end

  end # InstanceMethods

end # RCS::Worker::RESTController

require_relative 'worker_controller'

end # RCS::Worker
end # RCS
