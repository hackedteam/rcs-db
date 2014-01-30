require 'rcs-common/heartbeat'
require 'rcs-common/path_utils'

require_release 'rcs-db/db_layer'

module RCS
  module Money
    class HeartBeat < RCS::HeartBeat::Base
      component :money

      attr_reader :import_status

      before_heartbeat do
        @import_status = {}

        SUPPORTED_CURRENCIES.each do |currency|
          blocks_folder = BlocksFolder.discover(currency)
          @import_status[currency] = blocks_folder ? blocks_folder.import_percentage : nil
        end
      end

      def import_never_started?
        import_status.values.compact.empty?
      end

      def import_incomplete?
        incomplete = false
        import_status.values.each { |val| incomplete = true if val and val.to_i < 100 }
        incomplete
      end

      def status
        import_never_started? or import_incomplete? ? 'WARN' : 'OK'
      end

      def message
        if import_never_started?
          "Nothing loaded yet"
        else
          str = []

          import_status.each { |name, progress|
            next unless progress
            name = name.to_s.capitalize
            str << (progress.to_i == 100 ? "#{name} synchronized" : "#{name} sync @ #{progress}%")
          }

          str.join(", ")
        end
      end
    end
  end
end
