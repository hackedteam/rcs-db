require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe Connector do

  silence_alerts
  enable_license

  before { described_class.any_instance.stub(:setup_archive_node) }

  it 'uses the RCS::Tracer module' do
    expect(described_class).to respond_to :trace
    expect(subject).to respond_to :trace
  end

  it 'has no default type' do
    expect(subject.type).to be_nil
  end

  it 'has no default format' do
    expect(subject.format).to be_nil
  end

  it 'keep is true by default' do
    expect(subject.keep).to eql true
  end

  it 'has some indexes' do
    expect(subject.index_options).to have_key({enabled: 1})
    expect(subject.index_options).to have_key({keep: 1})
    expect(subject.index_options).to have_key({type: 1})
    expect(subject.index_options.keys.size).to eq 3
  end

  let(:target) { factory_create :target }

  let(:connector) { factory_create :connector, item: target }

  describe '#enabled scope' do

    let(:disable_connector) { factory_create :connector, item: target, enabled: false }

    before do
      connector
      disable_connector
      expect(described_class.all.count).to eql 2
    end

    it 'returns only enabled connectors' do
      expect(described_class.enabled.count).to eql 1
    end
  end

  describe '#matching' do

    let(:evidence) { factory_create :addressbook_evidence, target: target }

    let!(:matching_connector) { factory_create :connector, item: target }

    let!(:nonmatching_connector) { factory_create :connector, item: factory_create(:target) }

    before { expect(described_class.all.count).to eql 2 }

    it 'returns all the connectors that match the given evidence' do
      expect(described_class.matching(evidence).size).to eql 1
    end
  end

  describe '#match' do

    context 'when the path in blank' do

      let(:connector) { factory_create :connector, path: []}

      let(:evidence) { factory_create :addressbook_evidence, target: target }

      it 'returns true' do
        expect(connector.match?(evidence)).to be_true
      end
    end

    context 'when the path does not match the evidence path' do

      let(:connector) { factory_create :connector, item: target}

      let(:evidence) { factory_create :addressbook_evidence, agent: factory_create(:agent) }

      it 'returns false' do
        expect(connector.match?(evidence)).to be_false
      end
    end

    context 'when the path match the evidence path' do

      let(:operation) { factory_create :operation }

      let(:target) { factory_create :target, operation: operation }

      let(:agent) { factory_create :agent, target: target }

      let(:evidence) { factory_create :addressbook_evidence, agent: agent}

      let(:connector) { factory_create :connector, item: operation }
      it('returns true') { expect(connector.match?(evidence)).to be_true }

      let(:connector) { factory_create :connector, item: target }
      it('returns true') { expect(connector.match?(evidence)).to be_true }

      let(:connector) { factory_create :connector, item: agent }
      it('returns true') { expect(connector.match?(evidence)).to be_true }
    end
  end

  describe '#type' do

    context 'when is not included in the whitelist' do

      it 'raises a validation error' do
        expect { factory_create(:connector, item: target, type: :ROFLMAO) }.to raise_error(Mongoid::Errors::Validations)
      end
    end

    context "when is included in the whitelist" do

      it 'does not raise any validation error' do
        expect { factory_create(:connector, item: target, type: :dump, format: :json) }.not_to raise_error
      end
    end

    context "when archive and path refers to an operation" do

      it 'does not raise error' do
        expect { factory_create(:connector, type: :archive, path: [target.get_parent.id]) }.not_to raise_error
      end
    end

    context "when archive and path refers not to an operation" do

      it 'does not raise error' do
        expect { factory_create(:connector, type: :archive, path: [target.get_parent.id, target.id]) }.to raise_error(Mongoid::Errors::Validations)
      end
    end
  end

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

  describe '#format' do

    context 'when type is archive and format nil' do

      let(:connector) { factory_create(:connector, item: target.get_parent, type: :archive, format: nil) }

      it 'does not raise any validation error' do
        expect { connector }.not_to raise_error(Mongoid::Errors::Validations)
      end
    end

    context 'when type is dump and format is an unknow value' do

      let(:connector) { factory_create(:connector, item: target, type: :dump, format: :ROFLMAO) }

      it 'raises a validation error' do
        expect { connector }.to raise_error(Mongoid::Errors::Validations)
      end
    end
  end

  describe '#queued_count' do
    pending
  end

  describe '#evidence' do
    pending
  end

  describe '#destroy_archive_server_status' do
    pending
  end

  describe '#setup_archive_server' do
    pending
  end
end
