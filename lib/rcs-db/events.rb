#
#  Event handlers
#

# relatives
require_relative 'heartbeat'
require_relative 'parser'
require_relative 'rest'
require_relative 'sessions'
require_relative 'backup'
require_relative 'alert'

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

module HTTPHandler
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
    start_tls(:private_key_file => Config.instance.cert('DB_KEY'),
              :cert_chain_file => Config.instance.cert('DB_CERT'),
              :verify_peer => false)
    
    @connection_time = Time.now
    
    # to speed-up the processing, we disable the CGI environment variables
    self.no_environment_strings

    # set the max content length of the POST
    self.max_content_length = 200 * 1024 * 1024

    # get the peer name
    if get_peername
      @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    else
      @peer = 'unknown'
      @peer_port = 0
    end
    @closed = false
    trace :debug, "Connection from #{@peer}:#{@peer_port}"
  end

  def ssl_handshake_completed
    trace :debug, "[#{@peer}] SSL Handshake completed successfully (#{Time.now - @connection_time})"
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

  def self.sessionmanager
    @session_manager || SessionManager.instance
  end

  def self.restcontroller
    @rest_controller || RESTController
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
    size = (@http_post_content) ? @http_post_content.bytesize : 0

    # get it again since if the connection is keep-alived we need a fresh timing for each
    # request and not the total from the beginning of the connection
    @request_time = Time.now
    
    trace :debug, "[#{@peer}] REQ: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} #{size.to_s_bytes}"
    
    responder = nil
    
    # Block which fulfills the request (generate the data)
    operation = proc do
      
      trace :debug, "[#{@peer}] QUE: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} (#{Time.now - @request_time})" if Config.instance.global['PERF']

      generation_time = Time.now
      
      begin
        # parse all the request params
        request = prepare_request @http_request_method, @http_request_uri, @http_query_string, @http_cookie, @http_content_type, @http_post_content
        request[:peer] = peer
        request[:time] = @request_time
        
        # get the correct controller
        controller = HTTPHandler.restcontroller.get request
        
        # do the dirty job :)
        responder = controller.act!
        
        # create the response object to be used in the EM::defer callback
        
        reply = responder.prepare_response(self, request)
        
        # keep the size of the reply to be used in the closing method
        @response_size = reply.size
        trace :debug, "[#{@peer}] GEN: [#{request[:method]}] #{request[:uri]} #{request[:query]} (#{Time.now - generation_time}) #{@response_size.to_s_bytes}" if Config.instance.global['PERF']
        
        reply
      rescue Exception => e
        trace :error, e.message
        trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")
        
        # TODO: SERVER ERROR
        responder = RESTResponse.new(500, e.message)
        reply = responder.prepare_response(self, request)
        reply
      end
      
    end
    
    # Block which fulfills the reply (send back the data to the client)
    response = proc do |reply|
      
      reply.send_response
      
      # keep the size of the reply to be used in the closing method
      @response_size = reply.headers['Content-length'] || 0
    end

    # Let the thread pool handle request
    EM.defer(operation, response)
  end
  
end #HTTPHandler


class Events
  include RCS::Tracer
  
  def setup(port = 443)

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

        # reset the dashboard counter to be sure that on startup all the counters are empty
        Item.reset_dashboard
        # recalculate size statistics for operations and targets
        Item.restat
        EM::PeriodicTimer.new(60) { EM.defer(proc{Item.restat}) }

        # perform the backups
        EM::PeriodicTimer.new(60) { EM.defer(proc{ BackupManager.perform }) }

        # process the alert queue
        EM::PeriodicTimer.new(5) { EM.defer(proc{ Alerting.dispatch }) }
      end
    rescue RuntimeError => e
      # bind error
      if e.message.start_with? 'no acceptor'
        trace :fatal, "Cannot bind port #{Config.instance.global['LISTENING_PORT']}"
        return 1
      end
      raise
    end

  end

end #Events

end #Collector::
end #RCS::

