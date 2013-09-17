require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe ConnectorQueue do

  silence_alerts
  enable_license

  it 'does not inherit from NotificationQueue' do
    expect(described_class).not_to be_kind_of NotificationQueue
  end

  it 'has some indexes' do
    expect(described_class.index_options).to have_key(cid: 1)
    expect(described_class.index_options).to have_key(s: 1)
    expect(described_class.index_options.keys.size).to eql 2
  end

  it 'has a specific collection name' do
    expect(described_class.collection.name).to eql 'connector_queue'
  end

  describe '#evidence' do
    pending
  end

  context 'given an evidence and a connector' do

    let (:target) { factory_create(:agent) }
    let (:agent) { factory_create(:agent, target: target) }
    let (:evidence) { factory_create(:addressbook_evidence, agent: agent) }
    let (:connector) { factory_create(:connector, item: agent) }

    describe '#connector' do

      let(:connector_queue) do
        factory_create(:connector_queue_for_evidence, connector: connector, target: target, evidence: evidence)
      end

      it 'returns the connector document' do
        expect(connector_queue.connector).to eq(connector)
      end

      it 'caches the connector' do
        connector_queue.connector
        ::Connector.should_not_receive(:where)
        connector_queue.connector
      end

      context 'when the connector has been deleted' do

        before do
          connector_queue.update_attributes(connector_id: '51e7a8dfc7878313510000af')
        end

        it 'returns nil' do
          expect(connector_queue.connector).to be_nil
        end
      end
    end

    describe '#take' do

      before do
        factory_create(:connector_queue, connector: connector, data: {a: 1}, scope: :t1)
        factory_create(:connector_queue, connector: connector, data: {a: '1b'}, scope: :t1)
        factory_create(:connector_queue, connector: connector, data: {a: 2}, scope: :t2)
      end

      before { expect(described_class.size).to eq 3 }

      it 'returns the first element of the queue filtering by the argument' do
        expect(described_class.take(:t1).data).to eq('a' => 1)
        expect(described_class.take(:t2).data).to eq('a' => 2)
        expect(described_class.take(:t3)).to be_nil
      end
    end

    describe '#push_evidence' do

      before { described_class.push_evidence(connector, target, evidence) }

      it 'creates the expected document' do
        saved_document = described_class.first
        expected_data = {evidence_id: evidence.id, target_id: target.id, path: [target.path.first, target.id, evidence.aid]}
        expect(saved_document.data).to eq expected_data.stringify_keys
        expect(saved_document.connector).to eql connector
      end
    end
  end
end
