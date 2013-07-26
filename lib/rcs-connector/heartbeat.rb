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

      def archive_license?
        # TODO
        # LicenseManager.instance.check(:archive)
        true
      end

      def ping_archive_nodes
        return unless archive_license?
        RCS::DB::ArchiveNode.all.each { |node| node.ping! }
      end

      def update_status
        component_name = "RCS::Connector"
        # reset the status
        SystemStatus.my_status = 'OK'
        SystemStatus.my_error_msg = nil
        # our local ip address
        ip = Socket.gethostname rescue 'unknown'
        message = SystemStatus.my_error_msg || Dispatcher.status_message
        # report our status
        status = SystemStatus.my_status
        # create the stats hash
        stats = {:disk => SystemStatus.disk_free, :cpu => SystemStatus.cpu_load, :pcpu => SystemStatus.my_cpu_load(component_name)}
        # send the status to the db
        ::Status.status_update(component_name, ip, status, message, stats, 'connector', $version)
      rescue Exception => e
        trace :fatal, "Cannot perform status update: #{e.message}"
        trace :fatal, e.backtrace
      end

      def perform
        trace :debug, "HeartBeat#perform"
        update_status
        ping_archive_nodes
      end
    end
  end
end
