require 'rcs-common/trace'
require 'rcs-common/systemstatus'
require 'rcs-common/path_utils'
require 'socket'

require_release 'rcs-db/db_layer'
require_relative 'dispatcher'

module RCS
  module Connector
    module HeartBeat
      extend RCS::Tracer
      extend self

      def ping_archive_nodes
        RCS::DB::ArchiveNode.all.each do |node|
          trace :debug, "Updating status of archive node #{node.address}"
          node.ping!
        end
      end

      def status_and_message
        SystemStatus.reset

        if SystemStatus.my_status != 'OK'
          [SystemStatus.my_status, SystemStatus.my_error_msg]
        else
          status = Dispatcher.health.kind == :sick ? 'ERROR' : 'OK'
          [status, Dispatcher.health.desc]
        end
      end

      def ip
        Socket.gethostname rescue 'unknown'
      end

      def update_status
        component_name = "RCS::Connector"
        trace :debug, "Updating status of #{component_name}"
        status, message = status_and_message
        stats = {:disk => SystemStatus.disk_free, :cpu => SystemStatus.cpu_load, :pcpu => SystemStatus.my_cpu_load(component_name)}
        ::Status.status_update(component_name, ip, status, message, stats, 'connector', $version)
      end

      # @warning: Exceptions are suppressed here
      # @note: This method runs deferred in an Eventmachine thread
      def perform
        update_status
        ping_archive_nodes
      rescue Interrupt
        trace :fatal, "Heartbeat was interrupted because of a term signal"
      rescue Exception => e
        trace :fatal, "Exception during the heartbeat tick: #{e.message}, backtrace: #{e.backtrace}"
      end
    end
  end
end
