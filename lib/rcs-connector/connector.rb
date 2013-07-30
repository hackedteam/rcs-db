require 'eventmachine'
require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/path_utils'

require_release 'rcs-worker/license'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/connector_manager'
require_release 'rcs-db/db_objects/connector_queue'
require_release 'rcs-db/grid'
require_release 'rcs-db/alert'
require_release 'rcs-db/archive_node'
require_relative 'dispatcher'
require_relative 'heartbeat'

module RCS
module Connector

class Runner
  include Tracer
  extend Tracer

  def first_shard?
    current_shard == 'shard0000'
  end

  def current_shard
    RCS::DB::Config.instance.global['SHARD']
  end

  def heartbeat_interval
    @heartbeat_interval ||= RCS::DB::Config.instance.global['HB_INTERVAL']
  end

  def run
    EM.epoll
    EM.threadpool_size = 10

    EM::run do
      unless first_shard?
        trace :fatal, "Must be executed only on the first shard."
        break
      end

      EM::PeriodicTimer.new(heartbeat_interval) { HeartBeat.perform }

      EM.defer { Dispatcher.loop_dispatch_every(40) }

      trace :info, "rcs-connector module ready on shard #{current_shard}"
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
    Dir::mkdir(Dir.pwd + '/log/err') if not File.directory?(Dir.pwd + '/log/err')

    # initialize the tracing facility
    begin
      trace_init typ, ty
    rescue Exception => e
      puts e
      exit
    end

    begin
      build = File.read(Dir.pwd + '/config/VERSION_BUILD')
      $version = File.read(Dir.pwd + '/config/VERSION')
      trace :fatal, "Starting the RCS Connector #{$version} (#{build})..."

      # config file parsing
      return 1 unless RCS::DB::Config.instance.load_from_file

      # connect to MongoDB
      until RCS::DB::DB.instance.connect
        trace :warn, "Cannot connect to MongoDB, retrying..."
        sleep 5
      end

      # load the license from the db (saved by db)
      LicenseManager.instance.load_from_db

      # do the dirty job!
      Runner.new.run

      # never reached...

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

end
end
