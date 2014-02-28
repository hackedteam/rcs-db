require_release 'rcs-db/rest_response'

require 'rcs-common/trace'
require 'rcs-common/rest'
require 'json'

module RCS
  module Worker
    class RESTController
      include RCS::Tracer
      include RCS::Common::Rest

      # the parameters passed on the REST request
      attr_reader :request

      @controllers = {}

      def ok(*args)
        RCS::DB::RESTResponse.new STATUS_OK, *args
      end

      def not_found(message='', callback=nil)
        RCS::DB::RESTResponse.new(STATUS_NOT_FOUND, message, {}, callback)
      end

      def conflict(message='', callback=nil)
        RCS::DB::RESTResponse.new(STATUS_CONFLICT, message, {}, callback)
      end

      def bad_request(message='', callback=nil)
        RCS::DB::RESTResponse.new STATUS_BAD_REQUEST, *http_bad_request, callback
      end

      def server_error(message='', callback=nil)
        RCS::DB::RESTResponse.new(STATUS_SERVER_ERROR, message, {}, callback)
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
        # check we have a valid action
        return bad_request if @request[:action].nil?

        # make a copy of the params, handy for access and mongoid queries
        # consolidate URI parameters
        @params = @request[:params].clone unless @request[:params].nil?
        @params ||= {}
        unless @params.has_key? '_id'
          @params['_id'] = @request[:uri_params].first unless @request[:uri_params].first.nil?
        end

        response = __send__(@request[:action])

        return server_error('CONTROLLER_ERROR') if response.nil?

        response
      rescue Exception => e
        trace :error, "Server error: #{e.message}"
        trace :fatal, "Backtrace   : #{e.backtrace}"

        server_error(e.message)
      end

      # def cleanup
      #   # hook method if you need to perform some cleanup operation
      # end

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
          else
            return :bad_request
        end
      end
    end # RCS::Worker::RESTController
  end # RCS::Worker
end # RCS
