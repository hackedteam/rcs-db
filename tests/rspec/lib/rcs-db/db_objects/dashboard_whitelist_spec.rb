require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe DashboardWhitelist do

  silence_alerts

  it 'stores the document in the right collection' do
    expect(described_class.collection.name).to eq 'dashboard_whitelist'
  end

  it 'is correcly indexed' do
    expect(described_class.index_options.size).to eql 1
    expect(described_class.index_options).to have_key(iid: 1)
  end

  it 'uses the trace module' do
    expect(described_class).to respond_to(:trace)
  end

  describe '#rebuild' do

    context 'when no one is online' do

      before { factory_create(:user) }

      it('does not create any document') { expect(described_class.all.count).to be_zero }

      context 'and the collection was not empty' do

        before { factory_create(:dashboard_whitelist, item_id: '51dd6d3cc78783a3ba0005a8', cookies: ['a_cookie']) }

        before { expect(described_class).not_to be_empty }

        it 'empty it' do
          described_class.rebuild
          expect(described_class).to be_empty
        end
      end
    end

    context 'when there a no users' do

      it('does not create any document') { expect(described_class.all.count).to be_zero }
    end
  end

  context 'when some users are online' do

    let!(:user0) { factory_create(:user, dashboard_ids: ['51dd6d3cc78783a3ba0005a8']) }
    let!(:user1) { factory_create(:user, dashboard_ids: ['51dd6d3cc78783a3ba0005a8', '51dd6d3cc78783a3ba0005ab']) }
    let!(:user2) { factory_create(:user, dashboard_ids: ['51dd6d3cc78783a3ba0005ab']) }

    before do
      factory_create(:session, user: user0, cookie: 'cookie0')
      factory_create(:session, user: user1, cookie: 'cookie1')
    end

    describe '#rebuild' do

      it 'creates the expected documents' do
        described_class.rebuild
        expect(described_class.all.count).to eq 2
        expect(described_class.where(item_id: '51dd6d3cc78783a3ba0005a8').first.cookies).to eq %w[cookie0 cookie1]
        expect(described_class.where(item_id: '51dd6d3cc78783a3ba0005ab').first.cookies).to eq %w[cookie1]
      end
    end

    describe '#inject_cookies_on' do

      before { described_class.rebuild }

      it 'retuns the expected hash' do
        item = stub(id: '51dd6d3cc78783a3ba0005a8')
        hash = described_class.inject_cookies_on(item)
        expected_hash = {Moped::BSON::ObjectId.from_string(item.id) => %w[cookie0 cookie1]}
        expect(hash).to eq expected_hash
      end
    end
  end
end
