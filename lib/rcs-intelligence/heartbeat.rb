# encoding: utf-8

require 'rcs-common/heartbeat'
require 'rcs-common/path_utils'

require_release 'rcs-db/db_layer'

module RCS
  module Intelligence
    class HeartBeat < RCS::HeartBeat::Base
      component :intelligence

      def message
        Processor.status
      end
    end
  end
end
