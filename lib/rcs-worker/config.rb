#
#  Configuration parsing module
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/flatsingleton'

# system
require 'yaml'
require 'pp'
require 'optparse'

module RCS
module Worker

class Config
  include Singleton
  extend FlatSingleton
  include Tracer

  CONF_FILE = '/config/worker.yaml'

  DEFAULT_CONFIG= {'LISTENING_PORT' => 5150}

  attr_reader :global
  
  def initialize
    @global = {}
  end

  def load_from_file
    conf_file = Dir.pwd + CONF_FILE
    
    trace :info, "Loading configuration file #{conf_file} ..."
    
    # load the config in the @global hash
    begin
      File.open(conf_file, "r") do |f|
        @global = YAML.load(f.read)
      end
    rescue
      trace :fatal, "Cannot open config file [#{conf_file}]"
      return false
    end

    return true
  end

  def safe_to_file
    trace :info, "Writing configuration file..."
    conf_file = Dir.pwd + CONF_FILE

    # Write the @global into a yaml file
    begin
      File.open(conf_file, "w") do |f|
        f.write(@global.to_yaml)
      end
    rescue
      trace :fatal, "Cannot write config file [#{conf_file}]"
      return false
    end

    return true
  end

  def run(options)
    # load the current config
    load_from_file

    trace :info, "Current configuration:"
    pp @global

    # use the default values
    if options[:defaults] then
      @global = DEFAULT_CONFIG
    end

    # values taken from command line
    @global['LISTENING_PORT'] = options[:port] unless options[:port].nil?

    trace :info, "Final configuration:"
    pp @global

    # save the configuration
    safe_to_file
    
    return 0
  end

  # executed from rcs-collector-config
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def trace(level, message)
        puts message
      end
    end

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-worker-config [options]"

      # Define the options, and what they do
      opts.on( '-l', '--listen PORT', Integer, 'Listen on tcp/PORT' ) do |port|
        options[:port] = port
      end
      opts.on( '-X', '--defaults', 'Write a new config file with default values' ) do
        options[:defaults] = true
      end
      
      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end
    
    optparse.parse(argv)
    
    # execute the configurator
    return Config.run(options)
  end

end # Config

end # Worker::
end # RCS::