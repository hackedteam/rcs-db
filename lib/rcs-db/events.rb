#
#  Event handlers
#

# relatives
require_relative 'heartbeat'
require_relative 'parser'
require_relative 'rest'
require_relative 'sessions'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/systemstatus'

# system
require 'benchmark'
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'net/http'

module RCS
module DB

# require all the controllers
Dir[File.dirname(__FILE__) + '/rest/*.rb'].each do |file|
  require file
end

class HTTPHandler < EM::Connection
  include RCS::Tracer
  include EM::HttpServer
  include Parser

  attr_reader :peer
  attr_reader :peer_port

  def post_init
    # don't forget to call super here !
    super

    # timeout on the socket
    set_comm_inactivity_timeout 60

    # we want the connection to be encrypted with ssl
    start_tls(:private_key_file => Config.instance.file('DB_KEY'),
              :cert_chain_file => Config.instance.file('DB_CERT'),
              :verify_peer => false)


    # to speed-up the processing, we disable the CGI environment variables
    self.no_environment_strings

    # set the max content length of the POST
    self.max_content_length = 30 * 1024 * 1024

    # get the peer name
    @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    @closed = false
    trace :debug, "Connection from #{@peer}:#{@peer_port}"
  end

  def ssl_handshake_completed
    trace :debug, "SSL Handshake completed successfully"
  end

  def closed?
    @closed
  end

  def ssl_verify_peer(cert)
    #TODO: check if the client cert is valid
  end

  def unbind
    trace :debug, "Connection closed #{@peer}:#{@peer_port}"
    @closed = true
  end
  
  def process_http_request
    # the http request details are available via the following instance variables:
    #   @http_protocol
    #   @http_request_method
    #   @http_cookie
    #   @http_if_none_match
    #   @http_content_type
    #   @http_path_info
    #   @http_request_uri
    #   @http_query_string
    #   @http_post_content
    #   @http_headers
    
    #trace :debug, "[#{@peer}] Incoming HTTP Connection"
    trace :debug, "[#{@peer}] Request: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string}"
    
    responder = nil

    # Block which fulfills the request
    operation = proc do
      
      # parse all the request params
      request = prepare_request @http_request_method, @http_request_uri, @http_query_string, @http_cookie, @http_post_content
      request[:peer] = peer
      
      # get the correct controller
      controller = RESTController.get request[:controller]
      
      # If this controller cannot respond to the action, we need to patch this
      # by using the proper HTTP method (GET/POST/PUT/DELETE).
      # This is necessary to bypass a limitation in FLEX REST implementation.
      request[:action] = flex_override_action controller, request
      
      # get the proper session
      session = SessionManager.instance.get(request[:cookie])
      # if logging in, no session is present
      if session.nil?
        unless request[:controller].eql? 'AuthController' and request[:action].eql? :login
          trace :warn, "[#{request[:peer]}][#{request[:session_id]}] Invalid cookie"
          response = RESTController.not_authorized('INVALID_COOKIE')
        end
      end
      
      # do the dirty job :)
      begin
        responder ||= controller.act!(request, session)
      rescue Exception => e
        trace :error, "ERROR: " + e.message
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end
      
      # the controller job has finished, call the cleanup hook
      controller.cleanup
    end
    
    # Callback block to execute once the request is fulfilled
    callback = proc do |res|
      return RESTController.not_authorized('CONTROLLER_ERROR') if responder.nil?
      reply = responder.prepare_response(self)
      reply.send_response
    end
    
    # Let the thread pool handle request
    EM.defer(operation, callback)
  end

end #HTTPHandler


class Events
  include RCS::Tracer
  
  def setup(port = 4444)

    # main EventMachine loop
    begin

      # all the events are handled here
      EM::run do
        # if we have epoll(), prefer it over select()
        EM.epoll

        # set the thread pool size
        EM.threadpool_size = 50

        # we are alive and ready to party
        SystemStatus.my_status = SystemStatus::OK

        # start the HTTP REST server
        EM::start_server("0.0.0.0", port, HTTPHandler)
        trace :info, "Listening on port #{port}..."

        # send the first heartbeat to the db, we are alive and want to notify the db immediately
        # subsequent heartbeats will be sent every HB_INTERVAL
        HeartBeat.perform

        # set up the heartbeat (the interval is in the config)
        EM::PeriodicTimer.new(Config.instance.global['HB_INTERVAL']) { EM.defer(proc{ HeartBeat.perform }) }

        # timeout for the sessions (will destroy inactive sessions)
        EM::PeriodicTimer.new(60) { SessionManager.instance.timeout }

        # recalculate size statistics for operations, targets and backdoors
        Item.restat
        EM::PeriodicTimer.new(60) { Item.restat }
        
      end
    rescue Exception => e
      # bind error
      if e.message.eql? 'no acceptor' then
        trace :fatal, "Cannot bind port #{Config.instance.global['LISTENING_PORT']}"
        return 1
      end
      raise
    end

  end

end #Events

end #Collector::
end #RCS::

