require 'rcs-common/trace'
require 'fileutils'
require_relative 'extractor'
require_relative 'pool'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      def run
        @pool = Pool.new

        loop_and_wait do
          ConnectorQueue.scopes.each do |scope|
            next if @pool.has_thread?(scope)
            @pool.defer(scope) { dispatch(scope) }
          end

          @status = @pool.empty? ? "Idle" : "Working"
        end
      end

      def thread_with_errors
        @thread_with_errors ||= []
      end

      def status
        @status || "Idle"
      end

      def loop_and_wait
        loop do
          yield
          sleep(30)
        end
      end

      # @warning: Exceptions are suppressed here
      def dispatch(scope)
        loop do
          connector_queue = ConnectorQueue.take(scope)
          break unless connector_queue
          process(connector_queue)
        end
        thread_with_errors.delete(scope)
      rescue Exception => e
        trace :error, "Exception in dispatcher thread #{scope}: #{e.message}, #{e.backtrace}"
        thread_with_errors << scope
        thread_with_errors.uniq!
      end

      def process(connector_queue)
        trace :debug, "Processing #{connector_queue}"
        connector = connector_queue.connector
        data = connector_queue.data
        evidence = connector_queue.evidence

        if !connector
          trace :warn, "Was about to process #{connector_queue}, but the connector is missing."
        elsif !evidence
          trace :warn, "Was about to process #{connector_queue}, but the evidence is missing."
        elsif connector.remote?
          archive_node = connector.archive_node
          archive_node.send_evidence(evidence, data['path'])
        else
          dump(evidence, connector)
        end

        connector_queue.destroy
      end

      def dump(evidence, connector)
        trace :debug, "Dumping evidence #{evidence.id} with connector #{connector}"
        Extractor.new(evidence, connector.dest, connector.format).dump
      end
    end
  end
end
