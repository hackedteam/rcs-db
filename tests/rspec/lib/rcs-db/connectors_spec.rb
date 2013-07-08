require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'connectors'

module RCS
  module DB
    describe Connectors do

      silence_alerts
      enable_license

      it 'uses the tracer module' do
        expect(described_class).to respond_to :trace
      end

      describe '#add_to_queue' do

        let(:target) { factory_create :target }

        let(:evidence) { factory_create :addressbook_evidence, target: target }

        let(:connector) { factory_create :connector, item: target }

        before { ConnectorQueue.stub(:add) }

        context 'when the given evidence matches at least one connector' do

          before { Connector.stub(:matching).and_return([connector]) }

          it 'creates a ConnectorQueue doc' do
            ConnectorQueue.should_receive(:add).with(target, evidence, [connector])
            described_class.add_to_queue target, evidence
          end
        end

        context 'when the given evidence matches at least one connector with "keep" = true' do

          let(:connector) { factory_create :connector, item: target, keep: true }

          before { Connector.stub(:matching).and_return([connector]) }

          it 'returns :keep' do
            expect(described_class.add_to_queue(target, evidence)).to eql :keep
          end
        end

        context 'when the given evidence matches only connector with "keep" = false' do

          let(:connector) { factory_create :connector, item: target, keep: false }

          before { Connector.stub(:matching).and_return([connector]) }

          it 'returns :discard' do
            expect(described_class.add_to_queue(target, evidence)).to eql :discard
          end
        end

        context 'when the given evidence does not match any connector' do

          before { Connector.stub(:matching).and_return([]) }

          it 'returns nil' do
            expect(described_class.add_to_queue(target, evidence)).to be_nil
          end

          it 'does not create a ConnectorQueue doc' do
            ConnectorQueue.should_not_receive(:add)
            described_class.add_to_queue target, evidence
          end
        end
      end
    end
  end
end
