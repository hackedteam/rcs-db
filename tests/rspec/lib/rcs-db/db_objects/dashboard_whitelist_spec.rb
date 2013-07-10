require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe DashboardWhitelist do

  it 'stores the document in the right collection' do
    expect(described_class.collection.name).to eq 'dashboard_whitelist'
  end

  it 'is correcly indexed' do
    expect(described_class.index_options.size).to eql 1
    expect(described_class.index_options).to have_key(dids: 1)
  end

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

    context 'when the given id is fouded' do

      it 'returns true' do
        expect(described_class.include?("51dd6d3cc78783a3ba0005ab")).to be_true
      end
    end

    context 'when the given id is not fouded' do

      it 'returns false' do
        expect(described_class.include?('51dd6d3cc78783a3ba0005a8')).to be_false
      end
    end
  end

  describe '#rebuild' do
    pending
  end

  describe '#include_item?' do
    pending
  end
end
