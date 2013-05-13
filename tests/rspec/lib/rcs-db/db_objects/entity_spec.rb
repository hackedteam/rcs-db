require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'
require_db 'grid'

describe Entity do

  use_db
  silence_alerts
  enable_license

  describe 'relations' do
  	it 'should embeds many Handles' do
      subject.should respond_to :handles
    end

    it 'should embeds many Links' do
       subject.should respond_to :links
    end

    it 'should belongs to many Users' do
      subject.should respond_to :users
    end
  end


  context 'creating a new target' do

    it 'should create a new entity' do
      target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)

      entity = Entity.where(name: 'test-target').first
      entity.should_not be_nil
      entity.path.should eq target.path + [target._id]
    end

  end

  context 'creating a new entity' do
    it 'should alert and notify via push' do
      Entity.any_instance.should_receive(:alert_new_entity)
      Entity.any_instance.should_receive(:push_new_entity)

      operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      Entity.create!(name: 'test-entity', type: :person, path: [operation._id])
    end
  end

  context 'modifying an entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'test-entity', type: :person, path: [@operation._id])
    end

    it 'should notify name modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.name = 'test-modified'
      @entity.save
    end

    it 'should notify desc modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.desc = 'test-modified'
      @entity.save
    end

    it 'should notify position modification' do
      Entity.any_instance.should_receive(:push_modify_entity)

      @entity.last_position = {longitude: 45, latitude: 9, accuracy: 500, time: Time.now.to_i}
      @entity.save
    end

    it 'should assing and return last position correctly' do
      @entity.last_position = {longitude: 45, latitude: 9, accuracy: 500, time: Time.now.to_i}
      @entity.last_position[:longitude].should eq 45.0
      @entity.last_position[:latitude].should eq 9.0
      @entity.last_position[:accuracy].should eq 500
    end

    it 'should add and remove photos to/from grid' do
      @entity.add_photo("This_is_a_binary_photo")
      photo_id = @entity.photos.first
      photo_id.should be_a String

      @entity.del_photo(photo_id)
      expect { RCS::DB::GridFS.get(photo_id, @entity.path.last.to_s) }.to raise_error RuntimeError, /Cannot get content from the Grid/
    end

  end

  context 'destroying an entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'test-entity', type: :person, path: [@operation._id])
    end

    it 'should notify via push' do
      Entity.any_instance.should_receive(:push_destroy_entity)

      @entity.destroy
    end

    it 'should destroy all links' do
      entity2 = Entity.create!(name: 'test-entity-two', type: :person, path: [@operation._id])

      RCS::DB::LinkManager.instance.add_link(from: @entity, to: entity2, level: :manual, type: :peer)

      entity2.links.size.should be 1

      @entity.destroy

      entity2.reload
      entity2.links.size.should be 0
    end

    it 'should remove photos in the grid' do
      @entity.add_photo("This_is_a_binary_photo")
      photo_id = @entity.photos.first
      @entity.destroy
      expect { RCS::DB::GridFS.get(photo_id, @entity.path.last.to_s) }.to raise_error RuntimeError, /Cannot get content from the Grid/
    end
  end

  context 'merging two entities' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @first_entity = Entity.create!(name: 'entity-1', type: :target, path: [@operation._id], level: :automatic)
      @second_entity = Entity.create!(name: 'entity-2', type: :person, path: [@operation._id], level: :automatic)
      @third_entity = Entity.create!(name: 'entity-3', type: :person, path: [@operation._id], level: :automatic)
      @position_entity = Entity.create!(name: 'entity-position', type: :position, path: [@operation._id])
    end

    it 'should not merge incompatible entities' do
      expect { @first_entity.merge(@position_entity) }.to raise_error
      expect { @second_entity.merge(@first_entity) }.to raise_error
      expect { @position_entity.merge(@second_entity) }.to raise_error
    end

    it 'should merge handles' do
      @first_entity.handles.create!(level: :manual, type: 'skype', name: 'Test Name', handle: 'test.name')
      @second_entity.handles.create!(level: :manual, type: 'gmail', name: 'Test Name', handle: 'test.name@gmail.com')

      @first_entity.merge @second_entity

      @first_entity.handles.size.should be 2
      @first_entity.handles.last[:handle].should eq 'test.name@gmail.com'
    end

    it 'should be set to manual' do
      @first_entity.merge @second_entity
      @first_entity.level.should be :manual
    end

    it 'should merge links' do
      # lets create this scenario (links as follow):
      # 1 -> 2 (identity)
      # 2 -> 3 (peer)
      # 2 -> 4 (position)
      # we will merge 1 and 2 and it should result in:
      # 1 -> 3 (peer)
      # 1 -> 4 (position)
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @second_entity, level: :manual, type: :identity)
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @third_entity, level: :manual, type: :peer)
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @position_entity, level: :manual, type: :position)

      @first_entity.merge @second_entity
      @first_entity.reload
      @third_entity.reload
      @position_entity.reload

      # total link count
      @first_entity.links.size.should be 2

      # check if the links point to the right entities
      @first_entity.links.connected_to(@third_entity).count.should be 1
      @first_entity.links.connected_to(@position_entity).count.should be 1

      # check the backlinks
      @third_entity.links.size.should be 1
      @third_entity.links.first.linked_entity.should == @first_entity

      @position_entity.links.size.should be 1
      @position_entity.links.first.linked_entity.should == @first_entity
    end
  end

  context 'searching for peer' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @entity = Entity.any_in({path: [@target._id]}).first
    end

    it 'should find peer versus' do
      Aggregate.collection_class(@target._id).create!(type: 'sms', aid: 'test', day: Time.now.strftime('%Y%m%d'), count: 1, data: {peer: 'test', versus: :in})
      versus = @entity.peer_versus('test', 'sms')
      versus.should be_a Array
      versus.should include :in

      Aggregate.collection_class(@target._id).create!(type: 'sms', aid: 'test', day: Time.now.strftime('%Y%m%d'), count: 1, data: {peer: 'test', versus: :out})

      versus = @entity.peer_versus('test', 'sms')
      versus.should be_a Array
      versus.should include :out

      versus.should eq [:in, :out]
    end

    context 'with intelligence enabled' do

      it 'should return name from handle (from entities)' do
        @entity.handles.create!(type: 'phone', handle: 'test')

        name = Entity.name_from_handle('sms', 'test', @target._id.to_s)

        name.should eq @target.name
      end
    end

    context 'with intelligence disabled' do
      before do
        Entity.stub(:check_intelligence_license).and_return false
      end

      it 'should return name from handle (from addressbook)' do
        agent = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
        Evidence.collection_class(@target._id.to_s).create!(da: Time.now.to_i, aid: agent._id, type: 'addressbook', data: {name: 'test-addressbook', handle: 'test-a'}, kw: ['phone', 'test', 'a'])

        name = Entity.name_from_handle('sms', 'test-a', @target._id.to_s)

        name.should eq 'test-addressbook'
      end
    end
  end

  context 'given a ghost entity' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @first_entity = Entity.create!(name: 'entity-1', type: :target, path: [@operation._id], level: :automatic)
      @second_entity = Entity.create!(name: 'entity-2', type: :person, path: [@operation._id], level: :automatic)

      @ghost = Entity.create!(name: 'ghost', level: :ghost, type: :person, path: [@operation._id])
    end

    it 'should not be promoted to automatic with one link only' do
      @ghost.level.should be :ghost
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @ghost, level: :ghost, type: :know, versus: :out)
      @ghost.level.should be :ghost
    end

    it 'should be promoted to automatic with at least two link' do
      RCS::DB::LinkManager.instance.add_link(from: @first_entity, to: @ghost, level: :ghost, type: :know, versus: :out)
      RCS::DB::LinkManager.instance.add_link(from: @second_entity, to: @ghost, level: :ghost, type: :know, versus: :out)

      @ghost.level.should be :automatic

      @ghost.links.each do |link|
        link.level.should be :automatic
      end
    end
  end

  context 'creating a new handle' do
    before do
      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @entity = Entity.create!(name: 'entity', type: :target, path: [@operation._id], level: :automatic)
      @identity = Entity.create!(name: 'entity-same', type: :person, path: [@operation._id], level: :automatic)
    end

    it 'should check for identity with other entities' do
      @entity.handles.create!(type: 'phone', handle: 'test')

      @entity.links.size.should be 0
      @identity.links.size.should be 0

      @identity.handles.create!(type: 'phone', handle: 'test')
      @entity.reload
      @identity.reload

      @entity.links.size.should be 1
      @identity.links.size.should be 1

      @entity.links.first[:le].should eq @identity._id
    end
  end

end

describe EntityLink do

  use_db
  silence_alerts
  enable_license

  describe '#connected_to' do

    let (:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }

    let (:first_entity) { Entity.create! path: [operation.id] }

    let (:second_entity) { Entity.create! path: [operation.id] }

    it 'is a mongoid scope' do
      first_entity.links.connected_to(second_entity).kind_of?(Mongoid::Criteria).should be_true
    end

    context 'when there is a link' do

      before { RCS::DB::LinkManager.instance.add_link from: first_entity, to: second_entity }

      it 'returns the entities connected with the given one' do
        first_entity.links.connected_to(second_entity).count.should == 1
      end
    end

    context 'when there are no links' do

      it 'returns nothing' do
        first_entity.links.connected_to(second_entity).count.should be_zero
      end
    end
  end

  context 'setting parameters' do
    it 'should not duplicate info' do
      subject.add_info "a"
      subject.add_info "b"
      subject.add_info "a"
      subject.info.size.should be 2
      subject.info.should eq ['a', 'b']
    end

    context 'when versus is not set' do
      it 'should set versus if the first time' do
        subject.set_versus :in
        subject.versus.should be :in
      end
    end

    context 'when versus is already set' do
      before do
        subject.set_versus :in
      end

      it 'should not change versus' do
        subject.set_versus :in
        subject.versus.should be :in
      end

      it 'should upgrade to :both if different' do
        subject.set_versus :out
        subject.versus.should be :both
      end
    end

    it 'should upgrade type from :know to :peer' do
      subject.set_type :know
      subject.set_type :peer
      subject.type.should be :peer
    end

    it 'should not overwrite type with :know' do
      subject.set_type :peer
      subject.set_type :know
      subject.type.should be :peer
      subject.set_type :identity
      subject.set_type :know
      subject.type.should be :identity
    end

    it 'should upgrade level from :ghost to :automatic' do
      subject.set_level :ghost
      subject.set_level :automatic
      subject.level.should be :automatic
    end

    it 'should not overwrite level with :ghost' do
      subject.set_level :automatic
      subject.set_level :ghost
      subject.level.should be :automatic
      subject.set_level :manual
      subject.set_level :ghost
      subject.level.should be :manual
    end

    context 'deleting a ghost link' do
      before do
        @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
        @entity = Entity.create!(name: 'entity', type: :target, path: [@operation._id], level: :automatic)
        @ghost = Entity.create!(name: 'ghost', type: :person, path: [@operation._id], level: :ghost)

        RCS::DB::LinkManager.instance.add_link(from: @entity, to: @ghost, level: :ghost, type: :know)
      end

      it 'should delete the linked ghost entity' do
        RCS::DB::LinkManager.instance.del_link(from: @entity, to: @ghost)
        expect { Entity.find(@ghost._id) }.to raise_error Mongoid::Errors::DocumentNotFound
      end

      it 'should not delete the entity if not ghost' do
        @ghost.level = :automatic
        @ghost.save
        RCS::DB::LinkManager.instance.del_link(from: @entity, to: @ghost)
        Entity.find(@ghost._id).should eq @ghost
      end

    end
  end
end