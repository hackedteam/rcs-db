require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'

describe Entity do
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
    before do
      Entity.any_instance.stub(:alert_new_entity).and_return nil

      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer
    end

    it 'should create a new entity' do
      target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)

      entity = Entity.where(name: 'test-target').first
      entity.should_not be_nil
      entity.path.should eq target.path + [target._id]
    end

  end

  context 'creating a new entity' do
    before do
      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer
    end

    it 'should alert and notify via push' do
      Entity.any_instance.should_receive(:alert_new_entity)
      Entity.any_instance.should_receive(:push_new_entity)

      operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      Entity.create!(name: 'test-entity', type: :person, path: [operation._id])
    end
  end

  context 'modifying an entity' do
    before do
      Entity.any_instance.stub(:alert_new_entity).and_return nil

      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer

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

  end

  context 'destroying an entity' do
    before do
      Entity.any_instance.stub(:alert_new_entity).and_return nil
      Entity.any_instance.stub(:push_new_entity).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:push_modify_entity).and_return nil

      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer

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


    end
  end

  context 'merging two entities' do
    before do
      Entity.any_instance.stub(:alert_new_entity).and_return nil
      Entity.any_instance.stub(:push_new_entity).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:push_modify_entity).and_return nil
      EntityHandle.any_instance.stub(:check_intelligence_license).and_return true

      # connect and empty the db
      connect_mongoid
      empty_test_db
      turn_off_tracer

      @operation = Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new)
      @first_entity = Entity.create!(name: 'entity-1', type: :target, path: [@operation._id])
      @second_entity = Entity.create!(name: 'entity-2', type: :person, path: [@operation._id])
      @third_entity = Entity.create!(name: 'entity-3', type: :person, path: [@operation._id])
      @position_entity = Entity.create!(name: 'entity-position', type: :position, path: [@operation._id])
    end

    it 'should not merge incompatible entities' do
      expect {@first_entity.merge(@position_entity)}.to raise_error
      expect {@second_entity.merge(@first_entity)}.to raise_error
      expect {@position_entity.merge(@second_entity)}.to raise_error
    end

    it 'should merge handles' do
      @first_entity.handles.create!(level: :manual, type: 'skype', name: 'Test Name', handle: 'test.name')
      @second_entity.handles.create!(level: :manual, type: 'gmail', name: 'Test Name', handle: 'test.name@gmail.com')

      @first_entity.merge @second_entity

      @first_entity.handles.size.should be 2
      @first_entity.handles.last[:handle].should eq 'test.name@gmail.com'
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
      @first_entity.links.where(le: @third_entity._id).count.should be 1
      @first_entity.links.where(le: @position_entity._id).count.should be 1

      # check the backlinks
      @third_entity.links.size.should be 1
      @third_entity.links.first[:le].should eq @first_entity._id
      @position_entity.links.size.should be 1
      @position_entity.links.first[:le].should eq @first_entity._id
    end

  end
end
