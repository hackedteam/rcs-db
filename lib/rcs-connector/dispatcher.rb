require 'rcs-common/trace'
require 'fileutils'
require_relative 'extractor'
require_relative 'pool'
require_relative 'health'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      # @warning: Exceptions are suppressed here
      def run
        @pool = Pool.new(health)

        loop_and_wait do
          ConnectorQueue.scopes.each do |scope|
            next if @pool.has_thread?(scope)
            @pool.defer(scope) { dispatch(scope) }
          end

          health.change_to(:healthy, @pool.empty? ? "Idle" : "Working") unless health.still_sick?
        end
      rescue Exception => e
        health.change_to(:sick, "Some errors occurred. Check the logfile.")
        trace :fatal, "Exception in dispatcher tick: #{e.message}, backtrace: #{e.backtrace}"
        retry
      end

      def health
        @health ||= Health.new
      end

      def loop_and_wait
        loop do
          yield
          sleep(30)
        end
      end

      def dispatch(scope)
        loop do
          connector_queue = ConnectorQueue.take(scope)
          break unless connector_queue
          process(connector_queue)
        end
      end

      def process(connector_queue)
        trace :debug, "Processing #{connector_queue}"
        connector = connector_queue.connector
        data = connector_queue.data

        unless connector_queue
          trace :warn, "Was about to process #{connector_queue}, but the connector is missing."
          return
        end

        evidence = connector_queue.evidence

        unless evidence
          trace :warn, "Was about to process #{connector_queue}, but the evidence is missing."
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
