require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe ConnectorQueue do

  silence_alerts
  enable_license

  it 'does not inherit from NotificationQueue' do
    expect(subject).not_to be_kind_of NotificationQueue
  end

  it 'has an indexs' do
    expect(subject.index_options).to have_key({cids: 1})
    expect(subject.index_options.size).to eql 1
  end

  it 'does not use the default collection name' do
    expect(subject.collection.name).to eql 'connector_queue'
  end

  context 'given an evidence and a connector' do

    let (:target) { factory_create(:agent) }
    let (:agent) { factory_create(:agent, target: target) }
    let (:evidence) { factory_create(:addressbook_evidence, agent: agent) }
    let (:connector) { factory_create(:connector, item: agent) }

    describe '#connectors' do

      let(:connector_queue) { described_class.push_evidence([connector], target, evidence) }

      it 'returns the connector documents' do
        expect(connector_queue.connectors).to eq([connector])
      end

      it 'is a mongoid criteria' do
        expect(connector_queue.connectors).to respond_to(:where)
      end
    end

    describe '#complete' do

      let(:connector_queue) { described_class.push_evidence([connector], target, evidence) }

      before { expect(connector_queue.connector_ids).to eq([connector.id]) }

      it 'removes the given connector from the connector ids' do
        connector_queue.complete(connector)
        expect(connector_queue.reload.connector_ids).to eq([])
      end
    end

    describe '#completed?' do

      let(:connector_queue) { described_class.push_evidence([connector], target, evidence) }

      context 'when connector ids array is empty' do

        before { connector_queue.complete(connector) }

        it('returns true') { expect(connector_queue.completed?).to be_true }
      end

      context 'when connector ids array is not empty' do

        it('returns false') { expect(connector_queue.completed?).to be_false }
      end
    end

    describe '#take' do

      before do
        described_class.push([connector], {a: 1})
        described_class.push([connector], {a: 2})
      end

      before { expect(described_class.size).not_to be_zero }

      it 'returns the first element of the queue' do
        expect(described_class.take.data).to eq('a' => 1)
      end

      it 'does not change the size of the queue' do
        expect { described_class.take }.not_to change(described_class, :size)
      end
    end

    describe '#push_evidence' do

      before { described_class.push_evidence([connector], target, evidence) }

      it 'creates the expected document' do
        saved_document = described_class.first
        expected_data = {evidence_id: evidence.id, target_id: target.id, path: target.path + [evidence.aid]}
        expect(saved_document.data).to eq expected_data.stringify_keys
        expect(saved_document.connector_ids).to eql [connector.id]
      end
    end
  end
end
