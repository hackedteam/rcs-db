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
        EM.threadpool_size = 50

        EM::run do
          # set up the heartbeat (the interval is in the config)
          EM.defer(proc{ HeartBeat.perform })
          EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) { EM.defer(proc{ HeartBeat.perform }) }

          # once in a day trigger the batch that infer home and office position of each target entity
          EM.defer(proc{ Position.infer! })
          EM::PeriodicTimer.new(3600 * 24) { EM.defer(proc{ Position.infer! }) }

          # calculate and save the stats
          #EM::PeriodicTimer.new(60) { EM.defer(proc{ StatsManager.instance.calculate }) }

          # use a thread for the infinite processor waiting on the queue
          EM.defer(proc{ Processor.run })

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
