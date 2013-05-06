require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'

module RCS
module DB

  describe LinkManager do
    before do
      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer
    end

    context 'given two entities' do
      before do
        Entity.any_instance.stub(:alert_new_entity).and_return nil
        Entity.any_instance.stub(:push_new_entity).and_return nil
        RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil
        RCS::DB::LinkManager.any_instance.stub(:push_modify_entity).and_return nil

        @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
        @entity1 = Entity.create!(name: 'entity1', type: :target, path: [@operation._id], level: :automatic)
        @entity2 = Entity.create!(name: 'entity2', type: :target, path: [@operation._id], level: :automatic)
      end

      it 'should not link an entity on itself' do
        lambda {LinkManager.instance.add_link(from: @entity1, to: @entity1)}.should raise_error
      end
    end

  end

end
end

