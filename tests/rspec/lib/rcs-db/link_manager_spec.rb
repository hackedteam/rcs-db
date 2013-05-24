require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'link_manager'

module RCS
module DB

  describe LinkManager do

    use_db
    enable_license

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
        expect { LinkManager.instance.add_link(from: @entity1, to: @entity1) }.to raise_error
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

        link.linked_entity.should == @entity2
        linkback.linked_entity.should == @entity1

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

        @entity1.linked_to?(@entity3).should be_true
      end

      context 'when the is already a links from the two entities' do
        before do
          LinkManager.instance.add_link(from: @entity2, to: @entity3, level: :manual, type: :peer, versus: :in, info: 'test2')
        end

        it 'should not leave orphan links' do
          LinkManager.instance.move_links(from: @entity2, to: @entity3)
          @entity1.reload
          @entity2.reload
          @entity3.reload

          @entity3.links.size.should be 1
          @entity2.links.size.should be 0
          @entity1.links.size.should be 1

          @entity1.linked_to?(@entity3).should be_true
        end
      end
    end

    context 'given an entity with a handle (Alice) and another entity with no handles (Bob)' do

      silence_alerts

      let(:operation) { Item.create!(name: 'op', _kind: 'operation', path: [], stat: ::Stat.new) }

      let(:alice_number) { '+12345' }

      let(:entity_handle_attributes) { {name: 'Sweet alice', handle: alice_number, type: :phone} }

      let(:phone_handle) { EntityHandle.new entity_handle_attributes }

      let!(:alice) do
        Item.create!(name: 'alice', _kind: 'target', path: [operation.id], stat: ::Stat.new)
        Entity.where(name: 'alice').first.tap do |e|
          e.handles.create! entity_handle_attributes
        end
      end

      let!(:bob) { Entity.create!(name: 'bob', type: :person, path: [operation.id], level: :automatic) }

      describe '#check_identity' do

        before do
          LinkManager.instance.check_identity bob, phone_handle
          [bob, alice].each &:reload
        end

        it 'links Bob to Alice' do
          expect(bob.linked_to? alice).to be_true
        end

        it 'does not create any handles on Bob' do
          expect(bob.handles).to be_empty
        end

        it 'Creates an "indenty" link with a valid "info" and "versus"' do
          link = alice.links.first
          expect(link.type).to be :identity
          expect(link.versus).to be :both
          expect(alice.links.first.info).to include phone_handle.handle
        end
      end


      context 'when Alice has received an sms from Bob' do

        before do
          aggregate_type = 'sms'
          params = {data: {peer: alice_number, versus: :in}, type: aggregate_type, day: Time.now.strftime('%Y%m%d'), aid: 'agent_id', count: 1}
          Aggregate.target(alice.target_id).create! params
          Aggregate.target(alice.target_id).add_to_summary aggregate_type, alice_number
        end

        describe '#link_handle' do

          before do
            $STOP = 1
            LinkManager.instance.link_handle bob, phone_handle
            [bob, alice].each &:reload
          end

          it 'links Bob to Alice' do
            expect(bob.linked_to? alice).to be_true
          end

          # it 'Creates an "peer" link with a valid "info" and "versus"' do
          #   link = alice.links.first
          #   expect(link.info).to include phone_handle.handle
          #   expect(link.type).to eql :peer
          #   expect(link.versus).to eql :out
          # end
        end
      end

    end
  end

end
end
