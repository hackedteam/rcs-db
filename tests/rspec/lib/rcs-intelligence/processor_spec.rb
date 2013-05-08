require 'spec_helper'
require_db 'db_layer'
require_intelligence 'processor'

module RCS
module Intelligence

describe Processor do
  before do
    turn_off_tracer
    connect_mongoid
    empty_test_db
    Entity.any_instance.stub :alert_new_entity
    RCS::DB::LinkManager.any_instance.stub :alert_new_link
  end

  after { empty_test_db }


  it 'should use the Tracer module' do
    described_class.should respond_to :trace
  end


  describe '#process' do
    target_name = 'atarget'
    let! (:operation) { Item.create!(name: 'test-operation-x', _kind: 'operation', path: [], stat: ::Stat.new) }
    let! (:target) { Item.create!(name: target_name, _kind: 'target', path: [operation.id], stat: ::Stat.new) }
    let! (:entity) { Entity.where(name: target_name).first }

    context 'the item is an aggregate' do
      before do
        aggregate_class = Aggregate.collection_class target.id
        @aggregate = aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'sms', aid: 'agent_id', count: 1, data: {'peer' => 'harrenhal', 'versus' => :in})
        @queued_item = IntelligenceQueue.create! target_id: target.id, type: :aggregate, ident: @aggregate.id
      end


      it 'call #process_aggregate' do
        described_class.should_receive(:process_aggregate).with(entity, @aggregate)
        described_class.process @queued_item
      end
    end

    context 'the item is an evidence' do
      before do
        agent = Item.create! name: 'test-agent', _kind: 'agent', path: target.path+[target.id], stat: ::Stat.new
        @evidence = Evidence.collection_class(target._id).create!(da: Time.now.to_i, aid: agent._id, type: 'camera', data: {})
        @queued_item = IntelligenceQueue.create! target_id: target.id, type: :evidence, ident: @evidence.id
      end


      it 'call #process_evidence' do
        described_class.should_receive(:process_evidence)
        described_class.process @queued_item
      end
    end
  end


  describe '#run' do
    let(:queue_entry) { [:first_item, :second_item] }

    before { described_class.stub!(:sleep).and_return :sleeping }
    before { described_class.stub!(:loop).and_yield }

    context 'the IntelligenceQueue is not empty' do
      before { IntelligenceQueue.stub(:get_queued).and_return queue_entry }

      it 'should process the first entry' do
        described_class.should_receive(:process).with :first_item
        described_class.run
      end
    end

    context 'the IntelligenceQueue is empty' do
      before { IntelligenceQueue.stub(:get_queued).and_return nil }

      it 'should wait a second' do
        described_class.should_not_receive :process
        described_class.should_receive(:sleep).with 1
        described_class.run
      end
    end
  end


  describe '#process_evidence' do
    let(:evidence) { mock() }
    let(:entity) { mock() }

    context 'the type of the evidence is "addressbook"' do
      before { evidence.stub(:type).and_return 'addressbook' }
      before { Accounts.stub(:get_addressbook_handle).and_return nil }
      before { Accounts.stub(:add_handle).and_return nil }

      context 'the license is invalid' do
        before { described_class.stub(:check_intelligence_license).and_return false }

        it 'should not create any link' do
          Ghost.should_not_receive :create_and_link_entity
          described_class.process_evidence entity, evidence
        end
      end

      context 'the license is valid' do
        before { described_class.stub(:check_intelligence_license).and_return true }

        it 'should create a link' do
          Ghost.should_receive :create_and_link_entity
          described_class.process_evidence entity, evidence
        end
      end
    end
  end


  describe '#process_aggregate' do
    let! (:aggregate_class) { Aggregate.collection_class('testtarget') }
    let! (:aggregate_name) { Aggregate.collection_name('testtarget') }
    let! (:operation_x) { Item.create!(name: 'test-operation-x', _kind: 'operation', path: [], stat: ::Stat.new) }
    let! (:operation_y) { Item.create!(name: 'test-operation-y', _kind: 'operation', path: [], stat: ::Stat.new) }
    let! (:peer) { 'robert.baratheon' }

    before { EntityHandle.any_instance.stub(:check_intelligence_license).and_return true }

    context 'given a aggregate of type "sms"' do
      let!(:aggregate) { aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'sms', aid: 'agent_id', count: 1, data: {'peer' => peer, 'versus' => :in}) }

      let!(:entity_a) do
        Item.create!(name: 'test-target-a', _kind: 'target', path: [operation_x._id], stat: ::Stat.new)
        entity = Entity.where(name: 'test-target-a').first
        entity.create_or_update_handle :phone, peer, peer.capitalize
        entity
      end

      context 'if an entity (same operation) can be linked to it' do
        let!(:entity_b) do
          Item.create!(name: 'test-target-b', _kind: 'target', path: [operation_x._id], stat: ::Stat.new)
          Entity.where(name: 'test-target-b').first
        end

        it 'should create a link' do
          RCS::DB::LinkManager.instance.should_receive(:add_link).and_call_original

          described_class.process_aggregate entity_b, aggregate

          entity_a.reload
          entity_a.links.first.linked_entity == entity_b
        end
      end

      context 'if an entity (another operation) can be linked to it' do
        let!(:entity_b) do
          Item.create!(name: 'test-target-b', _kind: 'target', path: [operation_y._id], stat: ::Stat.new)
          Entity.where(name: 'test-target-b').first
        end

        it 'should not create a link' do
          RCS::DB::LinkManager.instance.should_not_receive :add_link
          described_class.process_aggregate entity_b, aggregate
        end
      end
    end
  end
end

end
end
