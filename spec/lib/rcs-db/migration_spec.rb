require 'spec_helper'
require_db 'migration'

module RCS
  module DB
    describe Migration do

      silence_alerts

      before do
        described_class.stub(:print)
      end

      if described_class.respond_to?(:fix_users_index_on_name)

        describe "#fix_users_index_on_name" do

          context 'when all the user names are unique' do

            before do
              factory_create(:user)
              factory_create(:user)
              User.create_indexes
              described_class.fix_users_index_on_name
            end

            it 'it recreates the indexes' do
              name_index = User.collection.indexes.to_a.find { |index| index['key'] == {'name' => 1} }
              expect(name_index['unique']).to be_true
            end
          end

          context 'when the user names are not unique' do

            before do
              2.times { User.collection.insert(name: 'foo') }
              described_class.fix_users_index_on_name
            end

            it 'create the index on name not-unique' do
              name_index = User.collection.indexes.to_a.find { |index| index['key'] == {'name' => 1} }
              expect(name_index['unique']).to be_nil
            end
          end
        end
      end

      if described_class.respond_to?(:add_pwd_changed_at_to_users)

        describe "#add_pwd_changed_at_to_users" do

          let(:now) { Time.new(2014, 01, 01).utc }

          before do
            User.any_instance.stub(:now).and_return(now)
          end

          context 'the pwd_changed_at attribute already exists' do

            let!(:user) { factory_create(:user) }

            before do
              expect(user).to respond_to(:pwd_changed_at)
              expect(user.password_expired?).to be_false
            end

            before do
              described_class.add_pwd_changed_at_to_users
              user.reload
            end

            it 'does not modify the user' do
              expect(user.pwd_changed_at).to eq(now)
              expect(user.password_expired?).to be_false
            end
          end

          context 'the pwd_changed_at attribute is nil' do

            let!(:user) do
              factory_create(:user).tap { |u|
                u.update_attribute(:pwd_changed_at, nil)
                u.update_attribute(:pwd_changed_cs, nil)
              }
            end

            before do
              expect(user.pwd_changed_at).to be_nil
              expect(user.pwd_changed_cs).to be_nil
              expect(user.password_expired?).to be_false
            end

            before do
              described_class.add_pwd_changed_at_to_users
              user.reload
            end

            it 'modify the user' do
              expect(user.pwd_changed_at).to eq(now)
              expect(user.pwd_changed_cs).not_to be_nil
              expect(user.password_expired?).to be_false
            end
          end
        end
      end
    end
  end
end
