require 'rcs-common/trace'
require 'pp'
require_relative 'db_objects/queue'

module RCS
  module DB
    module Connectors
      extend RCS::Tracer

      # If the evidence match some connectors, adds that evidence and that
      # collectors to the CollectorQueue.
      # @retuns :keep if evidence match at least one connector with keep = true,
      # otherwise :discard.
      def self.add_to_queue(target, evidence)
        matched_connectors = ::Connector.matching(evidence)
        return if matched_connectors.blank?

        ConnectorQueue.add(target, evidence, matched_connectors)
        discard_evidence = matched_connectors.inject(0) { |n, conn| n += (conn.keep) ? 1 : 0 } == 0
        discard_evidence ? :discard : :keep
      end
    end
  end
end
