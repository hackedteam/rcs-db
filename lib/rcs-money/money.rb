require 'rcs-common/path_utils'
require 'rcs-common/trace'
require 'rcs-common/component'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/license_component'

require 'bitcoin'
require_relative 'feathercoin'
require_relative 'importer'
require_relative 'blocks_folder'
require_relative 'heartbeat'

module RCS
  module Money
    SUPPORTED_CURRENCIES = [:feathercoin, :bitcoin, :litecoin, :namecoin, :freicoin]

    def self.support?(currency)
      currencies.include?(currency)
    end

    class Application
      include RCS::Component

      component(:money, name: "RCS Money")

      def heartbeat_interval
        @heartbeat_interval ||= RCS::DB::Config.instance.global['HB_INTERVAL']
      end

      def discover_and_import_all_currencies_blocks
        SUPPORTED_CURRENCIES.each do |currency|
          begin
            Importer.new(currency).run
          rescue Interrupt
            exit!(0)
          rescue Exception => ex
            trace(:error, "Unable to import #{currency}")
            trace(:error, "[#{ex.class}] #{ex.message}, #{ex.backtrace}")
          end
        end
      end

      def run(options)
        run_with_rescue do
          # config file parsing
          return 1 unless RCS::DB::Config.instance.load_from_file

          # connect to mongodb
          establish_database_connection(wait_until_connected: true)

          # load the license from the db (saved by db)
          LicenseManager.instance.load_from_db

          EM.epoll

          EM.threadpool_size = 20

          EM::run do
            EM.defer { HeartBeat.perform }
            EM::PeriodicTimer.new(heartbeat_interval) { HeartBeat.perform }

            EM.defer do
              loop do
                discover_and_import_all_currencies_blocks
                sleep(180)
              end
            end

            trace(:info, "#{component_name} module ready")
          end
        end
      end
    end
  end
end
