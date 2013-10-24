require 'eventmachine'

require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/path_utils'
require 'rcs-common/component'

require_release 'rcs-db/db_layer'
require_release 'rcs-db/connector_manager'
require_release 'rcs-db/db_objects/connector_queue'
require_release 'rcs-db/grid'
require_release 'rcs-db/alert'
require_release 'rcs-db/archive_node'
require_release 'rcs-db/license_component'

require_relative 'dispatcher'
require_relative 'heartbeat'

module RCS
  module Connector
    class Application
      include RCS::Component

      component :connector, name: "RCS Connector"

      def first_shard?
        current_shard == 'shard0000'
      end

      def current_shard
        RCS::DB::Config.instance.global['SHARD']
      end

      def heartbeat_interval
        @heartbeat_interval ||= RCS::DB::Config.instance.global['HB_INTERVAL']
      end

      def start_em_loop
        EM.epoll
        EM.threadpool_size = 10

        EM::run do
          unless first_shard?
            trace :fatal, "Must be executed only on the first shard."
            break
          end

          EM.defer { HeartBeat.perform }
          EM::PeriodicTimer.new(heartbeat_interval) { HeartBeat.perform }

          EM.defer { Dispatcher.run }

          trace :info, "#{component_name} module ready on shard #{current_shard}"
        end
      end

      def wait_for_connectors_license
        loop do
          break if LicenseManager.instance.check(:connectors)
          trace :info, "Connector license is disabled, going to sleep..."
          sleep 60
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

          wait_for_connectors_license

          # Starts the event machine reactor thread
          start_em_loop
        end
      end
    end
  end
end
