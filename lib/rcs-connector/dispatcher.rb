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
        @known_agents = []

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
          connector_queue.destroy
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
        type = connector_queue.type
        archive_node = connector.archive_node

        if !connector
          trace :warn, "Was about to process #{connector_queue}, but the connector is missing."
          return
        end

        if data['path'] and connector.remote?
          operation_id = data['path'].first
          agent_id = data['path'].last

          unless @known_agents.include?(agent_id)
            archive_node.send_agent(operation_id, agent_id)
            @known_agents << agent_id
          end
        end

        if type == :send_sync_event
          archive_node.send_sync_event(event: data['event'], params: data['params'], agent_id: data['path'].last)
          return
        end

        evidence = connector_queue.evidence

        if !evidence
          trace :warn, "Was about to process #{connector_queue}, but the evidence is missing."
          return
        end

        if type == :send_evidence
          archive_node.send_evidence(evidence, path: data['path'])
        elsif type == :dump_evidence
          dump(evidence, connector)
        end
      end

      def dump(evidence, connector)
        trace :debug, "Dumping evidence #{evidence.id} with connector #{connector}"
        Extractor.new(evidence, connector.dest, connector.format).dump
      end
    end
  end
end
