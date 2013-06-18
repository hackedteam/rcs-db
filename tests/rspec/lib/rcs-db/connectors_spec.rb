require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'connectors'

module RCS
  module DB
    describe Connectors do

      use_db
      silence_alerts
      enable_license
      stub_temp_folder

      it 'uses the tracer module' do
        expect(described_class).to respond_to :trace
      end

      describe '#add_to_queue' do

        let(:target) { factory_create :target }

        let(:evidence) { factory_create :addressbook_evidence, target: target }

        let(:connector) { factory_create :connector, item: target }

        before { ConnectorQueue.stub(:add) }

        context 'when the given evidence match at least one connector' do

          before { Connector.stub(:matching).and_return([connector]) }

          it 'create a ConnectorQueue doc' do
            ConnectorQueue.should_receive(:add).with(evidence, connector)
            result = described_class.add_to_queue evidence
          end
        end

        context 'when the given evidence match at least one connector (keep = true)' do

          let(:connector) { factory_create :connector, item: target, keep: true }

          before { Connector.stub(:matching).and_return([connector]) }

          it 'returns true' do
            expect(described_class.add_to_queue(evidence)).to eql true
          end
        end

        context 'when the given evidence match at least one connector (keep = false)' do

          let(:connector) { factory_create :connector, item: target, keep: false }

          before { Connector.stub(:matching).and_return([connector]) }

          it 'returns true' do
            expect(described_class.add_to_queue(evidence)).to eql false
          end
        end

        context 'when the given evidence does not match any connector' do

          before { Connector.stub(:matching).and_return([]) }

          it 'returns true' do
            expect(described_class.add_to_queue(evidence)).to eql true
          end

          it 'does not create a ConnectorQueue doc' do
            ConnectorQueue.should_not_receive(:add)
            result = described_class.add_to_queue evidence
          end
        end
      end

      describe '#dump' do

        let(:target) { factory_create :target }

        let(:evidence) { factory_create :mic_evidence, target: target }

        let(:connector) { factory_create :connector, item: target, dest: spec_temp_folder }

        it 'creates the expeted files' do
          described_class.dump(evidence, connector)
          pending
        end
      end
    end
  end
end
