require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe DashboardWhitelist::Document do
  it 'stores the document in the right collection' do
    expect(described_class.collection.name).to eq 'dashboard_whitelist'
  end

  it 'is correcly indexed' do
    expect(described_class.index_options.size).to eql 1
    expect(described_class.index_options).to have_key(dids: 1)
  end
end

describe DashboardWhitelist do

  silence_alerts

  it 'uses the trace module' do
    expect(described_class).to respond_to(:trace)
    expect(subject).to respond_to(:trace)
  end

  describe '#bson_obj_id' do

    it 'returns an ObjectId' do
      expect(described_class.bson_obj_id("51dd6d3cc78783a3ba0005ab")).to be_kind_of(Moped::BSON::ObjectId)
    end
  end

  describe '#include?' do

    before { factory_create(:dashboard_whitelist, ["51dd6d3cc78783a3ba0005ab"]) }

    context 'when the given id is founded' do

      it 'returns true' do
        expect(described_class.include?("51dd6d3cc78783a3ba0005ab")).to be_true
        expect(described_class.include?("51dd6d3cc78783a3ba0005ab")).to be_true
      end
    end

    context 'when the given id is not founded' do

      it 'returns false' do
        expect(described_class.include?('51dd6d3cc78783a3ba0005a8')).to be_false
      end
    end
  end

  describe '#rebuild' do

    it 'creates a DashboardWhitelist::Document' do
      expect { described_class.rebuild }.to change(described_class::Document, :first).from(nil)
    end

    context 'when a document already exists' do

      before { described_class.rebuild }

      it 'does not creates another one' do
        expect { described_class.rebuild }.not_to change(described_class::Document, :count)
      end
    end

    context 'when no one is online' do

      before { factory_create(:user) }

      it('returns an empty array') { expect(described_class.rebuild).to be_empty }
    end

    context 'when there a no users' do

      it('returns an empty array') { expect(described_class.rebuild).to be_empty }
    end

    context 'when some users are online' do

      let!(:user0) { factory_create(:user) }
      let!(:user1) { factory_create(:user) }
      let!(:user2) { factory_create(:user) }

      before do
        factory_create(:session, user: user0)
        factory_create(:session, user: user1)
      end

      it 'retuns their dashboard ids' do
        user0.update_attributes(dashboard_ids: ['51dd6d3cc78783a3ba0005a8'])
        user2.update_attributes(dashboard_ids: ['4f8d1bd0aef1de1140000002'])
        expect(described_class.rebuild).to eq ['51dd6d3cc78783a3ba0005a8']

        user0.update_attributes(dashboard_ids: ['51dd6d3cc78783a3ba0005a8'])
        user1.update_attributes(dashboard_ids: ['51dd6d3cc78783a3ba0005ab', '51dd6d3cc78783a3ba0005a8'])
        expect(described_class.rebuild).to eq ['51dd6d3cc78783a3ba0005a8', '51dd6d3cc78783a3ba0005ab']
      end
    end
  end

  describe '#include_item?' do

    let(:item) { factory_create(:target) }

    context 'when the argument is an item' do

      it 'calls #include? with the item id' do
        described_class.should_receive(:include?).with(item.id)
        described_class.include_item?(item)
      end
    end

    context 'when the argument is an id' do

      it 'calls #include? with the item id' do
        described_class.should_receive(:include?).with(item.id)
        described_class.include_item?(item.id)

        described_class.should_receive(:include?).with('51dd6d3cc78783a3ba0005a8')
        described_class.include_item?('51dd6d3cc78783a3ba0005a8')
      end
    end
  end
end
