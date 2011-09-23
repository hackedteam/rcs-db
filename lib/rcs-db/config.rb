#
#  Configuration parsing module
#

# from RCS::Common
require 'rcs-common/trace'

# system
require 'yaml'
require 'pp'
require 'optparse'

module RCS
module DB

class Config
  include Singleton
  include Tracer

  CONF_DIR = 'config'
  CONF_FILE = 'config.yaml'

  DEFAULT_CONFIG = {'CN' => 'localhost',
                    'CA_PEM' => 'rcs-ca.pem',
                    'DB_CERT' => 'rcs-db.crt',
                    'DB_KEY' => 'rcs-db.key',
                    'LISTENING_PORT' => 4444,
                    'HB_INTERVAL' => 30,
                    'WORKER_PORT' => 5150}

  attr_reader :global

  def initialize
    @global = {}
  end

  def load_from_file
    trace :info, "Loading configuration file..."
    conf_file = File.join Dir.pwd, CONF_DIR, CONF_FILE

    # load the config in the @global hash
    begin
      File.open(conf_file, "r") do |f|
        @global = YAML.load(f.read)
      end
    rescue
      trace :fatal, "Cannot open config file [#{conf_file}]"
      return false
    end

    if not @global['DB_CERT'].nil? then
      if not File.exist?(Config.instance.file('DB_CERT')) then
        trace :fatal, "Cannot open certificate file [#{@global['DB_CERT']}]"
        return false
      end
    end

    if not @global['DB_KEY'].nil? then
      if not File.exist?(Config.instance.file('DB_KEY')) then
        trace :fatal, "Cannot open private key file [#{@global['DB_KEY']}]"
        return false
      end
    end

    if not @global['CA_PEM'].nil? then
      if not File.exist?(Config.instance.file('CA_PEM')) then
        trace :fatal, "Cannot open CA file [#{@global['CA_PEM']}]"
        return false
      end
    end

    # to avoid problems with checks too frequent
    if (@global['HB_INTERVAL'] and @global['HB_INTERVAL'] < 10) then
      trace :fatal, "Interval too short, please increase it"
      return false
    end

    return true
  end

  def file(name)
    return File.join Dir.pwd, CONF_DIR, @global[name]
  end

  def safe_to_file
    conf_file = File.join Dir.pwd, CONF_DIR, CONF_FILE

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

    if options[:reset] then
      reset_admin options
      return 0
    end

    if options[:shard] then
      add_shard options
      return 0
    end

    # load the current config
    load_from_file

    trace :info, ""
    trace :info, "Current configuration:"
    pp @global

    # use the default values
    if options[:defaults] then
      @global = DEFAULT_CONFIG
    end

    # values taken from command line
    @global['CN'] = options[:cn] unless options[:cn].nil?
    @global['CA_PEM'] = options[:ca_pem] unless options[:ca_pem].nil?
    @global['DB_CERT'] = options[:db_cert] unless options[:db_cert].nil?
    @global['DB_KEY'] = options[:db_key] unless options[:db_key].nil?
    @global['LISTENING_PORT'] = options[:port] unless options[:port].nil?
    @global['HB_INTERVAL'] = options[:hb_interval] unless options[:hb_interval].nil?
    @global['WORKER_PORT'] = options[:worker_port] unless options[:worker_port].nil?
    @global['BACKUP_DIR'] = options[:backup] unless options[:backup].nil?

    trace :info, ""
    trace :info, "Final configuration:"
    pp @global

    # save the configuration
    safe_to_file

    return 0
  end

  def reset_admin(options)
    trace :info, "Resetting 'admin' password..."

    http = Net::HTTP.new('localhost', 4444)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    resp = http.request_post('/auth/reset', {pass: options[:reset]}.to_json, nil)
    trace :info, resp.body
  end

  def add_shard(options)
    trace :info, "Adding this host as db shard..."

    http = Net::HTTP.new(options[:db_address] || 'localhost', options[:db_port] || 4444)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    # login
    account = {:user => options[:user], :pass => options[:pass] }
    resp = http.request_post('/auth/login', account.to_json, nil)
    unless resp['Set-Cookie'].nil?
      cookie = resp['Set-Cookie']
    else
      puts "Invalid authentication"
      return
    end

    # send the request
    res = http.request_post('/shard/create', {host: options[:shard]}.to_json, {'Cookie' => cookie})
    puts res.body

    # logout
    http.request_post('/auth/logout', nil, {'Cookie' => cookie})
  end

  # executed from rcs-db-config
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
      opts.banner = "Usage: rcs-db-config [options]"

      opts.separator ""
      opts.separator "Application layer options:"
      opts.on( '-l', '--listen PORT', Integer, 'Listen on tcp/PORT' ) do |port|
        options[:port] = port
      end
      opts.on( '-b', '--db-heartbeat SEC', Integer, 'Time in seconds between two heartbeats' ) do |sec|
        options[:hb_interval] = sec
      end
      opts.on( '-w', '--worker-port PORT', Integer, 'Listen on tcp/PORT for worker' ) do |port|
        options[:worker_port] = port
      end
      opts.on( '-n', '--CN CN', String, 'Common Name for the server' ) do |cn|
        options[:cn] = cn
      end

      opts.separator ""
      opts.separator "Certificates options:"
      opts.on( '-c', '--ca-pem FILE', 'The certificate file (pem) of the issuing CA' ) do |file|
        options[:ca_pem] = file
      end
      opts.on( '-t', '--db-cert FILE', 'The certificate file (crt) used for ssl communication' ) do |file|
        options[:db_cert] = file
      end
      opts.on( '-k', '--db-key FILE', 'The certificate file (key) used for ssl communication' ) do |file|
        options[:db_key] = file
      end

      opts.separator ""
      opts.separator "General options:"
      opts.on( '-X', '--defaults', 'Write a new config file with default values' ) do
        options[:defaults] = true
      end
      opts.on( '-B', '--backup-dir DIR', String, 'The directory to be used for backups' ) do |dir|
        options[:backup] = dir
      end
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end

      opts.separator ""
      opts.separator "Utilities:"
      opts.on( '-u', '--user USERNAME', 'rcs-db username' ) do |user|
        options[:user] = user
      end
      opts.on( '-p', '--password PASSWORD', 'rcs-db password' ) do |password|
        options[:pass] = password
      end
      opts.on( '-d', '--db-address HOSTNAME', 'Use the rcs-db at HOSTNAME' ) do |host|
        options[:db_address] = host
      end
      opts.on( '-P', '--db-port PORT', Integer, 'Connect to tcp/PORT on rcs-db' ) do |port|
        options[:db_port] = port
      end
      opts.on( '-R', '--reset-admin PASS', 'Reset the password for user \'admin\'' ) do |pass|
        options[:reset] = pass
      end
      opts.on( '-S', '--add-shard ADDRESS', 'Add ADDRESS as a db shard (sys account required)' ) do |shard|
        options[:shard] = shard
      end

    end

    optparse.parse(argv)

    # execute the configurator
    return Config.instance.run(options)
  end

end #Config

end #DB::
end #RCS::