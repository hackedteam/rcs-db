# The main file of the ocr
require 'rcs-common/path_utils'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/exec'
require_release 'rcs-db/alert'
require_release 'rcs-db/sessions'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/component'

require_relative 'processor'
require_relative 'heartbeat'

module RCS
  module OCR
    class Application
      include RCS::Component

      component :ocr, name: "OCR Processor"

      def start_em_loop
        EM.epoll
        EM.threadpool_size = 50

        EM::run do
          # set up the heartbeat (the interval is in the config)
          EM.defer(proc{ HeartBeat.perform })
          EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) { EM.defer(proc{ HeartBeat.perform }) }

          # use a thread for the infinite processor waiting on the queue
          EM.defer(proc{ Processor.run })
        end
      end

      def wait_for_ocr_license
        unless LicenseManager.instance.check :ocr
          database.mongo_connection.drop_collection 'ocr_queue'

          # do nothing...
          trace :info, "OCR license is disabled, going to sleep..."

          loop { sleep(60) }
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

          wait_for_ocr_license

          # the infinite processing loop
          start_em_loop
        end
      end
    end # Application::
  end #DB::
end #RCS::
