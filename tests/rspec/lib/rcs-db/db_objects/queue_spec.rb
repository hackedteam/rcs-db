require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe ConnectorQueue do
  use_db
  silence_alerts
  enable_license

  it 'inherits from NotificationQueue' do
    expect(subject).to be_kind_of NotificationQueue
  end

  it 'has a "flag" attribute' do
    expect(subject.attributes).to have_key "flag"
  end

  it 'has an index on the "flag" attribute' do
    expect(subject.index_options).to have_key({flag: 1})
  end

  it 'does not use the default collection name' do
    expect(subject.collection.name).to eql 'connector_queue'
  end

  context 'given an evidence and a connector' do

    let (:agent) { factory_create(:agent) }
    let (:evidence) { factory_create(:addressbook_evidence, agent: agent) }
    let (:connector) { factory_create(:connector, item: agent) }

    describe '#add' do

      before { described_class.add evidence, connector }

      it 'creates a valid NotificationQueue document' do
        saved_document = described_class.first
        expect(saved_document.ev_id).to eql evidence._id
        expect(saved_document.cn_id).to eql connector._id
      end
    end
  end
end
