require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe Connector do
  use_db
  silence_alerts
  enable_license

  it 'uses the RCS::Tracer module' do
    expect(described_class).to respond_to :trace
    expect(subject).to respond_to :trace
  end

  it 'has "JSON" as default type' do
    expect(subject.type).to eql 'JSON'
  end

  it 'keep is true by default' do
    expect(subject.keep).to eql true
  end

  it 'has an index on "enabled"' do
    expect(subject.index_options).to have_key({enabled: 1})
  end

  let(:target) { factory_create :target }

  let(:connector) { factory_create :connector, item: target }

  describe '#delete_if_item' do

    context 'when the given id is in the connector\'s path' do

      it 'deletes the connector' do
        connector.delete_if_item target.id
        expect { connector.reload }.to raise_error Mongoid::Errors::DocumentNotFound
      end
    end

    context 'when the given id isn\'t in the connector\'s path' do

      it 'does not deletes the connector' do
        connector.delete_if_item "randomid"
        expect { connector.reload }.not_to raise_error
      end
    end
  end

  describe '#update_path' do

    context 'when the given id is the last id of connector\'s path' do

      it 'changes the connector\'s path with the given one' do
        connector.update_path target.id, [1, 2]
        expect(connector.reload.path).to eql [1, 2]
      end
    end

    context 'when the given id isn\'t the last id of the connector\'s path' do

      it 'does not change the connector\'s path' do
        operation_id = target.path.first
        connector.update_path operation_id, [1, 2]
        expect(connector.reload.path).not_to eql [1, 2]
      end
    end

    context 'when the given id isn\'t in the connector\'s path' do

      it 'does not change the connector\'s path' do
        connector.update_path "randomid", [1, 2]
        expect(connector.reload.path).not_to eql [1, 2]
      end
    end
  end
end
