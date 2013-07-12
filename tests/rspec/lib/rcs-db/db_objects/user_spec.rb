require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe User do

  describe '#online' do

    it 'is a scope' do
      expect(described_class.online).to be_kind_of(Mongoid::Criteria)
    end

    context 'given some users' do

      before { 3.times { factory_create(:user) } }

      before { expect(User.count).to eql(3) }

      context 'when a user is online' do

        let(:online_users) { User.all.to_a[0..1] }

        before do
          online_users.each { |u| factory_create(:session, user: u) }
        end

        it 'returns that user' do
          expect(described_class.online.to_a.sort).to eql(online_users.sort)
        end
      end
    end
  end
end
