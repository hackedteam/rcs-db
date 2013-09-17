require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'connector_manager'

module RCS
  module DB
    describe ConnectorManager do

      silence_alerts
      enable_license

      it 'uses the tracer module' do
        expect(described_class).to respond_to :trace
      end

      let(:subject) { described_class }

      before do
        ConnectorQueue.should respond_to(:push_evidence)
        ::Connector.should respond_to(:enabled)

        # Prevent making an http request when the connector is created
        # to ensure the status of the archive node
        ::Connector.any_instance.stub(:setup_archive_node)
      end

      describe '#process_sync_event' do

        let(:target) { factory_create :target }

        let(:agent) { factory_create :agent, target: target }

        context 'when the given agent matches the connector path' do

          let!(:connector) { factory_create :remote_connector, path: [target.path.first] }

          it 'puts the connector in the connector queue' do
            ConnectorQueue.should_receive(:push_sync_event).with(connector, :sync_start, agent, {})
            subject.process_sync_event(agent, :sync_start)
          end

          context 'but the connector is not enabled' do

            before { connector.update_attributes(enabled: false) }

            it 'does not puts the connector in the connector queue' do
              ConnectorQueue.should_not_receive(:push_sync_event)
              subject.process_sync_event(agent, :sync_start)
            end
          end
        end

        context 'when the given agent does not match the connector path' do

          let(:another_operation) { factory_create(:operation) }

          let!(:connector) { factory_create :remote_connector, path: [another_operation.id] }

          it 'does not puts the connector in the connector queue' do
            ConnectorQueue.should_not_receive(:push_sync_event)
            subject.process_sync_event(agent, :sync_start)
          end
        end
      end

      describe '#process_evidence' do

        let(:target) { factory_create :target }

        let(:evidence) { factory_create :addressbook_evidence, target: target }

        let(:connector) { factory_create :connector, item: target }

        context 'when the given evidence matches at least one connector' do

          before { ::Connector.stub(:matching).and_return([connector]) }

          it 'creates a ConnectorQueue doc' do
            expect {
              described_class.process_evidence(target, evidence)
            }.to change(ConnectorQueue, :size).from(0).to(1)
          end
        end

        context 'when the given evidence matches at least one connector with "keep" = true' do

          let(:connector) { factory_create :connector, item: target, keep: true }

          before { ::Connector.stub(:matching).and_return([connector]) }

          it 'returns :keep' do
            expect(described_class.process_evidence(target, evidence)).to eql :keep
          end
        end

        context 'when the given evidence matches only connector with "keep" = false' do

          let(:connector) { factory_create :connector, item: target, keep: false }

          before { ::Connector.stub(:matching).and_return([connector]) }

          it 'returns :discard' do
            expect(described_class.process_evidence(target, evidence)).to eql :discard
          end
        end

        context 'when the given evidence does not match any connector' do

          before { ::Connector.stub(:matching).and_return([]) }

          it 'returns :keep' do
            expect(described_class.process_evidence(target, evidence)).to eql :keep
          end

          it 'does not create a ConnectorQueue doc' do
            ConnectorQueue.should_not_receive(:push_evidence)
            described_class.process_evidence target, evidence
          end
        end
      end
    end
  end
end
