#
# The main file of the worker
#

# from RCS::Common
require 'rcs-common/trace'

# form System
require 'optparse'

module RCS
module Worker

class Worker
  include Tracer

  attr_reader :type

  def initialize(db_file, type)

    # db file where evidence to be processed are stored
    @db_file = db_file

    # type of evidences to be processed
    @type = type

    trace :info, "Working on evidence stored in #{@db_file}."
    trace :info, "Processing evidence of type #{@type.to_s}."
  end
  
  def process
    trace :info, "Starting to process evidence."
    sleep 1
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
      w = RCS::Worker::Worker.new(file, options[:type])
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
      opts.banner = "Usage: rcs-worker [options] <databse file>"
        
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