# encoding: utf-8

require 'rcs-common/heartbeat'
require 'rcs-common/path_utils'

require_release 'rcs-db/db_layer'
require_relative 'dispatcher'

module RCS
  module Connector
    class HeartBeat < RCS::HeartBeat::Base
      component :connector

      before_heartbeat do
        RCS::DB::ArchiveNode.all.each do |node|
          trace :debug, "Updating status of archive node #{node.address}"

          node.ping!

          if node.status.ok? and Dispatcher.thread_with_errors.include?(node.address)
            node.update_status(status: ::Status::ERROR, info: "Some errors occured. Check the logfile.")
          end
        end
      end

      def message
        Dispatcher.status
      end
    end
  end
end
