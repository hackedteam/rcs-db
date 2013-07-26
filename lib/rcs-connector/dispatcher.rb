require 'rcs-common/trace'
require 'fileutils'
require_relative 'extractor'
require_relative 'pool'

module RCS
  module Connector
    module Dispatcher
      extend RCS::Tracer
      extend self

      def dispatch
        return unless can_dispatch?

        @status_message = "working"

        pool = Pool.new

        scopes = ConnectorQueue.scopes

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

        @status_message = "idle"
      end

      def status_message
        (@status_message || "idle").capitalize
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
        else
          dump(evidence, connector)
        end

        connector_queue.destroy
      end

      def can_dispatch?
        return true if connectors_license?
        trace :warn, "Cannot dispatch connectors queue due to license limitation."
        @status_message = "license needed"
        false
      end

      def connectors_license?
        LicenseManager.instance.check(:connectors)
      end

      def dump(evidence, connector)
        trace :debug, "Dumping evidence #{evidence.id} with connector #{connector}"
        Extractor.new(evidence, connector.dest, connector.format).dump
      end
    end
  end
end
