require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe User do

  describe '#online' do

    it 'is a scope' do
      expect(described_class.online).to be_kind_of(Mongoid::Criteria)
    end

    let(:online_users) { User.all.to_a[0..1] }

    before do
      3.times { factory_create(:user) }
      online_users.each { |u| factory_create(:session, user: u) }
    end

    it 'returns online users' do
      expect(described_class.online.to_a.sort).to eql(online_users.sort)
    end
  end

  context 'when a user updates his dashboard_ids' do

    let!(:user) { factory_create(:user) }

    it 'rebuilds the watched item list' do
      described_class.any_instance.should_receive(:rebuild_watched_items)
      user.update_attributes(dashboard_ids: ['517552a0c78783c10d000005'], desc: 'i like trains')
    end
  end

  context 'when a user updates his attributes but not the dashboard_ids' do

    let!(:user) { factory_create(:user) }

    it 'does not rebuild the watched item list' do
      described_class.any_instance.should_not_receive(:rebuild_watched_items)
      user.update_attributes(desc: 'i like trains')
    end
  end

  context 'when a user is created' do

    it 'does not rebuild the watched item list' do
      described_class.any_instance.should_not_receive(:rebuild_watched_items)
      factory_create(:user)
    end
  end
end
