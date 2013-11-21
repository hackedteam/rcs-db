#  The main file of the Intelligence module (correlation)
require 'rcs-common/path_utils'

require_release 'rcs-db/db'
require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/link_manager'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'

require_relative 'heartbeat'
require_relative 'processor'

require 'eventmachine'

module RCS
  module Intelligence
    class Application
      include RCS::Component

      component :intelligence, name: "RCS Intelligence"

      def start_em_loop
        EM.epoll
        EM.threadpool_size = 15

        EM::run do
          # set up the heartbeat (the interval is in the config)
          EM.defer { HeartBeat.perform }

          EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) do
            EM.defer { HeartBeat.perform }
          end

          # once in a day trigger the batch that infer home and office position of each target entity
          EM.defer { Position.infer! }

          EM::PeriodicTimer.new(3600 * 24) do
            EM.defer { Position.infer! }
          end

          # use a thread for the infinite processor waiting on the queue
          EM.defer { Processor.run }

          trace :info, "Intelligence Module ready!"
        end
      end

      def run(options)
        run_with_rescue do
          # initialize random number generator
          srand(Time.now.to_i)

          trace_setup

          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # ensure the temp dir is present
          Dir::mkdir(RCS::DB::Config.instance.temp) if not File.directory?(RCS::DB::Config.instance.temp)

          # connect to MongoDB
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          # do the dirty job!
          start_em_loop
        end
      end
    end # Application::
  end #DB::
end #RCS::
