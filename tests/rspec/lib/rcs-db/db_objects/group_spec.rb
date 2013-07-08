require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe Group do

  use_db
  silence_alerts
  enable_license

  # Stub #defer.
  # Do not run #Group callbacks in a separate thread, otherwise tests should wait
  # the thread's end.
  before do
    described_class.any_instance.stub(:defer).and_yield
  end

  describe '#remove_user_callback' do

    context 'given a group with one user' do

      let(:user) { factory_create :user }

      let(:group) { factory_create :group, users: [user] }

      before { expect(group.users.count).to eql 1 }

      it 'is triggered when a user is removed' do
        group.should_receive(:remove_user_callback)
        group.users.delete(user)
      end

      context 'and no items' do

        it 'does not rebuild access control' do
          described_class.should_not_receive(:rebuild_access_control)
          group.users.delete(user)
        end
      end

      context 'and one item' do

        let(:operation) { factory_create :operation }

        let(:target) { factory_create :target, operation: operation, users: [user] }

        before { group.items << operation }

        before { user.recent_ids << target.id }

        it 'rebuilds access control' do
          described_class.should_receive(:rebuild_access_control).once
          group.users.delete(user)
        end

        it 'removes the item id from the user recent_ids' do
          expect{ group.users.delete(user) }.to change(user, :recent_ids).from([target.id]).to([])
        end
      end
    end
  end
end
