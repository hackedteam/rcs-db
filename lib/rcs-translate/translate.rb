# The main file of the translator
require 'rcs-common/path_utils'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/alert'
require_release 'rcs-db/sessions'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/component'

require_relative 'processor'

module RCS
  module Translate
    class Application
      include RCS::Component

      component :translate, name: "TRANSLATE Processor"

      def wait_for_translation_license
        unless LicenseManager.instance.check :translation
          RCS::DB::DB.instance.drop_collection 'trans_queue'

          # do nothing...
          trace :info, "TRANSLATE license is disabled, going to sleep..."

          loop { sleep(60) }
        end
      end

      # the main of the collector
      def run(options)
        run_with_rescue do
          # initialize random number generator
          srand(Time.now.to_i)

          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # connect to MongoDB
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          wait_for_translation_license

          # the infinite processing loop
          Processor.run
        end
      end
    end # Application::
  end #DB::
end #RCS::
