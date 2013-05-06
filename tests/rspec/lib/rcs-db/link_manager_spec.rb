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

      it 'should link two entity without parameters' do
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity1)
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity2)
        RCS::DB::LinkManager.any_instance.should_receive(:alert_new_link).with([@entity1, @entity2])

        LinkManager.instance.add_link(from: @entity1, to: @entity2)

        @entity1.links.size.should be 1
        @entity2.links.size.should be 1

        link = @entity1.links.first
        linkback = @entity2.links.first

        link.le.should eq @entity2._id
        linkback.le.should eq @entity1._id

        link.level.should be :automatic
        linkback.level.should be :automatic
      end

      it 'should link two entity with parameters set' do
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')

        link = @entity1.links.first
        linkback = @entity2.links.first

        link.level.should be :manual
        linkback.level.should be :manual

        link.type.should be :peer
        linkback.type.should be :peer

        link.versus.should be :in
        linkback.versus.should be :out

        link.info.should eq ['test']
        linkback.info.should eq ['test']
      end

      it 'should not duplicate a link' do
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')

        @entity1.links.size.should be 1
        @entity2.links.size.should be 1
      end

      it 'should keep consistency of the versus' do
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')

        @entity1.links.first.versus.should be :in
        @entity2.links.first.versus.should be :out

        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :out, info: 'test')

        @entity1.links.first.versus.should be :both
        @entity2.links.first.versus.should be :both
      end

      it 'should upgrade from ghost to automatic' do
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :ghost, type: :peer, versus: :in, info: 'test')

        @entity1.links.first.level.should be :ghost
        @entity2.links.first.level.should be :ghost

        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :automatic, type: :peer, versus: :in, info: 'test')

        @entity1.links.first.level.should be :automatic
        @entity2.links.first.level.should be :automatic

      end

      it 'should not upgrade from automatic to ghost' do
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :automatic, type: :peer, versus: :in, info: 'test')
        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :ghost, type: :peer, versus: :in, info: 'test')

        @entity1.links.first.level.should be :automatic
        @entity2.links.first.level.should be :automatic
      end
    end

    context 'given two linked entities' do
      before do
        Entity.any_instance.stub(:alert_new_entity).and_return nil
        Entity.any_instance.stub(:push_new_entity).and_return nil
        RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil

        @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
        @entity1 = Entity.create!(name: 'entity1', type: :target, path: [@operation._id], level: :automatic)
        @entity2 = Entity.create!(name: 'entity2', type: :target, path: [@operation._id], level: :automatic)

        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')
      end

      it 'should edit the link' do
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity1)
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity2)

        LinkManager.instance.edit_link(from: @entity1, to: @entity2, type: :peer, versus: :out, rel: 3)

        # should overwrite them (instead of setting to both)
        @entity1.links.first.versus.should be :out
        @entity2.links.first.versus.should be :in

        @entity1.links.first.rel.should be 3
      end

      it 'should delete the link' do
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity1)
        RCS::DB::LinkManager.any_instance.should_receive(:push_modify_entity).with(@entity2)

        LinkManager.instance.del_link(from: @entity1, to: @entity2)

        @entity1.links.size.should be 0
        @entity2.links.size.should be 0
      end
    end

    context 'given two linked entities and a third one' do
      before do
        Entity.any_instance.stub(:alert_new_entity).and_return nil
        Entity.any_instance.stub(:push_new_entity).and_return nil
        RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil

        @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
        @entity1 = Entity.create!(name: 'entity1', type: :target, path: [@operation._id], level: :automatic)
        @entity2 = Entity.create!(name: 'entity2', type: :target, path: [@operation._id], level: :automatic)
        @entity3 = Entity.create!(name: 'entity3', type: :target, path: [@operation._id], level: :automatic)

        LinkManager.instance.add_link(from: @entity1, to: @entity2, level: :manual, type: :peer, versus: :in, info: 'test')
      end

      it 'should move a link from one entity to another' do
        LinkManager.instance.move_links(from: @entity2, to: @entity3)
        @entity1.reload
        @entity2.reload
        @entity3.reload

        @entity1.links.size.should be 1
        @entity2.links.size.should be 0
        @entity3.links.size.should be 1

        link = @entity1.links.first
        linkback = @entity3.links.first

        link.le.should eq @entity3._id
        linkback.le.should eq @entity1._id
      end

    end


  end

end
end

