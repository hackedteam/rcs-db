# encoding: utf-8

require 'rcs-common/heartbeat'
require 'rcs-common/path_utils'

require_release 'rcs-db/db_layer'

require_relative 'queue_manager'

module RCS
  module Worker
    class HeartBeat < RCS::HeartBeat::Base
      component :worker

      def message
        how_many_processing = QueueManager.how_many_processing
        how_many_processing > 0 ? "Processing evidence from #{how_many_processing} agents." : 'Idle...'
      end
    end
  end
end
