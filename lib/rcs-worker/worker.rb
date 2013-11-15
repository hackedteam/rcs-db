  # The main file of the worker
require 'rcs-common/path_utils'

# relatives
require_relative 'call_processor'
require_relative 'heartbeat'
require_relative 'backlog'
require_relative 'statistics'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/component'

# form System
require 'digest/md5'
require 'optparse'

# from bundle
require 'eventmachine'

module RCS
  module Worker
    class Application
      include RCS::Component

      component :worker, name: "RCS Worker"

      def start_em_loop
        EM.epoll
        EM.threadpool_size = 50

        EM::run do
          EM.defer(proc{ HeartBeat.perform })

          EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) do
            EM.defer { HeartBeat.perform }
          end

          # calculate and save the stats
          EM::PeriodicTimer.new(60) { EM.defer(proc{ StatsManager.instance.calculate }) }

          # this is the actual polling
          EM.defer { QueueManager.run! }

          trace :info, "#{component_name} '#{RCS::DB::Config.instance.global['SHARD']}' ready!"
        end
      end

      def run(options)
        run_with_rescue do
          trace_setup

          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # connect to MongoDB
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          # Start the eventmachine reactor threads
          start_em_loop
        end
      end
    end
  end # Worker::
end # RCS::
