require 'spec_helper'
require_db 'db_layer'

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
      Entity.any_instance.stub(:alert_new_entity).and_return nil

      # connect and empty the db
      connect_mongo
      empty_test_db

      # create fake object to be used by the test
      #@target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
    end
  end


end
