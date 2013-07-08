require 'rcs-common/trace'
require 'rcs-common/systemstatus'
require 'rcs-common/path_utils'
require 'socket'

require_release 'rcs-db/db_layer'
require_relative 'dispatcher'

module RCS
  module Connector
    class HeartBeat
      extend RCS::Tracer

      def self.perform
        # reset the status
        SystemStatus.my_status = 'OK'
        SystemStatus.my_error_msg = nil

        # report our status to the db
        component = "RCS::Connector"

        # our local ip address
        ip = Socket.gethostname rescue 'unknown'

        message = SystemStatus.my_error_msg || Dispatcher.status_message

        # report our status
        status = SystemStatus.my_status

        # create the stats hash
        stats = {:disk => SystemStatus.disk_free, :cpu => SystemStatus.cpu_load, :pcpu => SystemStatus.my_cpu_load(component)}

        begin
          # send the status to the db
          ::Status.status_update component, ip, status, message, stats, 'connector', $version
        rescue Exception => e
          trace :fatal, "Cannot perform status update: #{e.message}"
          trace :fatal, e.backtrace
        end
      end
    end
  end
end
