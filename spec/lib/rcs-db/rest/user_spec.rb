require 'spec_helper'
require_db 'db_layer'

module RCS
module DB

  describe UserController do

    let!(:user) { factory_create(:user) }
    let!(:session) { factory_create(:session, user: user) }

    let!(:operation) { factory_create(:operation) }
    let!(:entity) { factory_create(:target_entity) }
    let!(:target) { factory_create(:target) }
    let!(:target2) { factory_create(:target) }
    let!(:target3) { factory_create(:target) }
    let!(:target4) { factory_create(:target) }
    let!(:target5) { factory_create(:target) }

    before do
      # skip check of current user privileges
      described_class.any_instance.stub :require_auth_level

      # stub the #ok method and then #not_found methods
      described_class.any_instance.stub(:ok) { |*args| args.respond_to?(:first) && args.size == 1 ? args.first : args }
    end

    def create_rest_instance_with_params(params = {})
      described_class.new.tap do |inst|
        inst.instance_variable_set('@params', params)
        inst.instance_variable_set('@session', session)
      end
    end

    describe '#add_recent' do

      it 'should add the item to the recents in the User' do
        instance = create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target.id})
        instance.add_recent

        session.user.recent_ids.should_not be_empty
      end

      it 'should not duplicate entries' do
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target.id}).add_recent

        session.user.recent_ids.size.should be 1
      end

      it 'should limit the numbe of recents to 5' do
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target2.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target3.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target4.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'target', 'id' => target5.id}).add_recent
        create_rest_instance_with_params({'section' => 'operations', 'type' => 'operation', 'id' => operation.id}).add_recent

        session.user.recent_ids.size.should be 5
      end

      it 'should also accept items in the intelligence section' do
        create_rest_instance_with_params({'section' => 'intelligence', 'type' => 'operation', 'id' => operation.id}).add_recent
        create_rest_instance_with_params({'section' => 'intelligence', 'type' => 'entity', 'id' => entity.id}).add_recent

        session.user.recent_ids.size.should be 2
      end

    end

  end

end
end

