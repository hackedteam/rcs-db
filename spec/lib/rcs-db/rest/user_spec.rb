require 'spec_helper'
require_db 'rest'
require_db 'db_layer'

module RCS
  module DB
    describe UserController do

      let!(:user) { factory_create(:user) }

      let!(:session) { factory_create(:session, user: user) }

      let!(:operation) { factory_create(:operation) }

      let!(:entity) { factory_create(:target_entity) }

      5.times do |i|
        let!(:"target#{i}") { factory_create(:target) }
      end

      before do
        described_class.any_instance.stub(:mongoid_query).and_yield

        # skip check of current user privileges
        described_class.any_instance.stub :require_auth_level

        # stub the #ok method and then #not_found methods
        described_class.any_instance.stub(:ok) { |*args| args.respond_to?(:first) && args.size == 1 ? args.first : args }
      end

      def subject(params = {})
        described_class.new.tap do |inst|
          inst.instance_variable_set('@params', params)
          inst.instance_variable_set('@session', session)
        end
      end

      describe '#add_recent' do

        before do
          expect(user.recent_ids).to be_empty
        end

        it 'should add the item to the recents in the User' do
          instance = subject('section' => 'operations', 'type' => 'target', 'id' => target1.id)
          instance.add_recent

          expect(user.recent_ids).not_to be_empty
        end

        it 'should not duplicate entries' do
          2.times do
            subject('section' => 'operations', 'type' => 'target', 'id' => target1.id).add_recent
          end

          expect(user.recent_ids.size).to eq(1)
        end

        it 'should limit the numbe of recents to 5' do
          5.times do |i|
            target_id = __send__(:"target#{i}").id
            subject('section' => 'operations', 'type' => 'target', 'id' => target_id).add_recent
          end

          subject('section' => 'operations', 'type' => 'operation', 'id' => operation.id).add_recent

          expect(user.recent_ids.size).to eq(5)
        end

        it 'should also accept items in the intelligence section' do
          subject('section' => 'intelligence', 'type' => 'operation', 'id' => operation.id).add_recent
          subject('section' => 'intelligence', 'type' => 'entity', 'id' => entity.id).add_recent

          expect(user.recent_ids.size).to eq(2)
        end
      end
    end
  end
end

