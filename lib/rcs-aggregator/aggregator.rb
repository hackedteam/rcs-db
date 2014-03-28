# The main file of the aggregator
require 'rcs-common/path_utils'

require_release 'rcs-db/db'
require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/position/point'
require_release 'rcs-db/position/positioner'
require_release 'rcs-db/position/resolver'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/component'

require_relative 'processor'
require_relative 'heartbeat'

module RCS
  module Aggregator
    class Application
      include RCS::Component

      component :aggregator, name: "RCS Aggregator"

      def start_em_loop
        EM.epoll
        EM.threadpool_size = 15

        EM::run do
          # defer the first heartbeat
          EM.defer { HeartBeat.perform }

          # each HB_INTERVAL secs run the heartbeat (in a new thread from the pool)
          EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) do
            EM.defer { HeartBeat.perform }
          end

          # use a thread for the infinite processor waiting on the queue
          EM.defer { Processor.run }

          trace :info, "Aggregator Module ready!"
        end
      end

      def wait_for_correlation_license
        unless LicenseManager.instance.check(:correlation)
          database.drop_collection('aggregator_queue')

          trace(:info, "Correlation license is disabled, going to sleep...")

          # do nothing...
          loop { sleep(60) }
        end
      end

      def run(options)
        run_with_rescue do
          # initialize random number generator
          srand(Time.now.to_i)

          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # ensure the temp dir is present
          Dir::mkdir(RCS::DB::Config.instance.temp) if not File.directory?(RCS::DB::Config.instance.temp)

          # connect to MongoDB
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          wait_for_correlation_license

          # the infinite processing loop
          start_em_loop
        end
      end
    end # Application::
  end #DB::
end #RCS::
