require 'rcs-common/trace'
require 'fileutils'
require_relative 'extractor'
require_relative 'pool'
require_relative 'dispatcher_status'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      # @warning: Exceptions are suppressed here
      def loop_dispatch_every(seconds)
        loop do
          dispatch
          sleep(seconds)
        end
      rescue Exception => e
        status.change_to(:sick, "Some errors occurred. Check the logfile.")
        trace :fatal, "Exception in dispatcher tick: #{e.message}, backtrace: #{e.backtrace}"
        retry
      end

      def status
        @status ||= DispatcherStatus.new
      end

      def dispatch
        scopes = ConnectorQueue.scopes
        return if scopes.empty?

        status.change_to(:healthy, "Working")

        pool = Pool.new

        scopes.each do |scope|
          pool.defer(scope) do
            loop do
              connector_queue = ConnectorQueue.take(scope)
              break unless connector_queue
              process(connector_queue)
            end
          end
        end

        pool.wait_done
        status.change_to(:healthy, "Idle")
      end

      def process(connector_queue)
        trace :debug, "Processing #{connector_queue}"
        connector = connector_queue.connector
        data = connector_queue.data

        unless connector_queue
          trace :warn, "Was about process #{connector_queue}, but the connector is missing."
          return
        end

        evidence = connector_queue.evidence

        unless evidence
          trace :warn, "Was about process #{connector_queue}, but the evidence is missing."
          return
        end

        if connector.archive?
          archive_node = connector.archive_node
          archive_node.send_evidence(evidence, data['path'])
          connector_queue.destroy
        else
          dump(evidence, connector)
          connector_queue.destroy
        end
      end

      def dump(evidence, connector)
        trace :debug, "Dumping evidence #{evidence.id} with connector #{connector}"
        Extractor.new(evidence, connector.dest, connector.format).dump
      end
    end
  end
end
