  # The main file of the worker
require 'rcs-common/path_utils'

# relatives
require_relative 'call_processor'
require_relative 'statistics'
require_relative 'events'
require_relative 'backlog'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/license_component'

require_relative 'db'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/component'
require 'rcs-common/winfirewall'

# from bundle
require 'eventmachine'

module RCS
  module Worker
    class Application
      include RCS::Component

      component :worker, name: "RCS Worker"

      def setup_firewall
        return unless WinFirewall.exists?

        rule_name = "RCS_FWR_RULE_coll_to_worker"
        port = RCS::DB::Config.instance.global['LISTENING_PORT']-1
        WinFirewall.del_rule(rule_name)
        WinFirewall.add_rule(action: :allow, direction: :in, name: rule_name, local_port: port, remote_ip: 'LocalSubnet', protocol: :tcp)
      end

      def run(options)
        run_with_rescue do
          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # connect to MongoDB
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          setup_firewall

          # Start the eventmachine reactor threads
          Events.new.setup(RCS::DB::Config.instance.global['LISTENING_PORT']-1)
        end
      end
    end
  end # Worker::
end # RCS::
