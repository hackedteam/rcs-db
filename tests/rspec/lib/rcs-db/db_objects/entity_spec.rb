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
      connect_mongo
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
      connect_mongo
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
      connect_mongo
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

  context 'destroying an evidence' do
    before do
      Entity.any_instance.stub(:alert_new_entity).and_return nil
      Entity.any_instance.stub(:push_new_entity).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:alert_new_link).and_return nil
      RCS::DB::LinkManager.any_instance.stub(:push_modify_entity).and_return nil

      # connect and empty the db
      connect_mongo
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
  end

end
