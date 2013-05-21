require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'position/point'
require_intelligence 'processor'

module RCS
module Intelligence

describe Processor do

  use_db
  enable_license
  silence_alerts

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
        aggregate_class = Aggregate.target target.id
        @aggregate = aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 1, data: {'peer' => 'harrenhal', 'versus' => :in})
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

        it 'should create a link' do
          Ghost.should_receive :create_and_link_entity
          described_class.process_evidence entity, evidence
        end
      end
    end
  end

  describe '#process_aggregate' do
    let!(:aggregate_class) { Aggregate.target('testtarget') }
    let!(:aggregate_name) { "aggregate.testtarget" }
    let!(:operation_x) { Item.create!(name: 'test-operation-x', _kind: 'operation', path: [], stat: ::Stat.new) }
    let!(:operation_y) { Item.create!(name: 'test-operation-y', _kind: 'operation', path: [], stat: ::Stat.new) }
    let!(:number_of_alice) { '00112345' }
    let!(:number_of_bob) { '00145678' }

    context 'given an aggregate of type "position"' do
      let(:position_aggregate_of_bob) { aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :position, aid: 'agent_id') }

      it 'calls #process_position_aggregate' do
        described_class.should_receive :process_position_aggregate
        entity = mock()
        described_class.process_aggregate entity, position_aggregate_of_bob
      end
    end

    context 'given a aggregate of type "sms"' do
      let!(:sms_aggregate_of_bob) { aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 3,
        data: {'peer' => number_of_alice, 'versus' => :in, 'sender' => number_of_bob}) }

      # Create Alice (entity) with an handle (her phone number)
      let!(:entity_alice) do
        Item.create! name: 'alice', _kind: 'target', path: [operation_x._id], stat: ::Stat.new
        entity = Entity.where(name: 'alice').first
        entity.create_or_update_handle :phone, number_of_alice, number_of_alice.capitalize
        entity
      end

      context 'if an entity (same operation) can be linked to it' do
        let!(:entity_bob) do
          Item.create! name: 'bob', _kind: 'target', path: [operation_x._id], stat: ::Stat.new
          Entity.where(name: 'bob').first
        end

        it 'should create a link' do
          described_class.process_aggregate entity_bob, sms_aggregate_of_bob

          entity_alice.reload
          expect(entity_alice.linked_to?(entity_bob)).to be_true
        end

        context 'the "info" attribute of the created link' do

          let :created_link do
            described_class.process_aggregate entity_bob, sms_aggregate_of_bob
            entity_alice.reload.links.first
          end

          it 'contains the handles of the two linked entities' do
            created_link
            expect(created_link.info).to include "#{number_of_bob} #{number_of_alice}"
          end

          # this situation should not be happen in version 9.0.0
          context 'when the aggregate does not have a "sender" attribute' do

            before do
              sms_aggregate_of_bob.data['sender'] = nil
              sms_aggregate_of_bob.save!
              created_link
            end

            it 'contains the handle of other entity' do
              expect(created_link.info).to include number_of_alice
            end
          end
        end
      end

      context 'if an entity (another operation) can be linked to it' do
        let!(:entity_bob) do
          Item.create!(name: 'test-target-b', _kind: 'target', path: [operation_y._id], stat: ::Stat.new)
          Entity.where(name: 'test-target-b').first
        end

        it 'should not create a link' do
          RCS::DB::LinkManager.instance.should_not_receive :add_link
          described_class.process_aggregate entity_bob, sms_aggregate_of_bob
        end
      end
    end
  end

  describe '#process_position_aggregate' do

    def create_position_aggregate_for target, params
      data = {'position' => [params[:lon], params[:lat]], 'radius' => params[:rad]}
      info = [{'start' => params[:start], 'end' => params[:end]}]
      Aggregate.target(target).create! type: :position, info: info, data: data,  aid: 'agent_id', count: 1, day: Time.new(2013, 01, 01)
    end

    let!(:operation) { Item.create!(name: 'opx', _kind: 'operation', path: [], stat: ::Stat.new) }

    let!(:target_bob) { Item.create! name: 'bob', _kind: 'target', path: [operation.id], stat: ::Stat.new }
    let!(:target_alice) { Item.create! name: 'alice', _kind: 'target', path: [operation.id], stat: ::Stat.new }
    let!(:target_eve) { Item.create! name: 'eve', _kind: 'target', path: [operation.id], stat: ::Stat.new }

    let!(:bob) { Entity.where(name: 'bob').first }
    let!(:alice) { Entity.where(name: 'alice').first }
    let!(:eve) { Entity.where(name: 'eve').first }

    let(:midday) { Time.new 2013, 01, 01, 12, 00, 00 }
    let(:london_eye) { [51.503894, 0.119390] } #lat, lon
    let(:near_london_eye) { [51.50391, 0.11961] } #lat, lon

    before { Entity.create_indexes }

    context 'when two target entities have been in the same place at the same time' do

      let!(:bob_position) { create_position_aggregate_for target_bob, lat: london_eye[0], lon: london_eye[1], rad: 10, start: midday, end: midday + 40.minutes }
      let!(:alice_position) { create_position_aggregate_for target_alice, lat: london_eye[0], lon: london_eye[1], rad: 12, start: midday, end: midday + 42.minutes }
      let!(:eve_position) { create_position_aggregate_for target_eve, lat: 10, lon: 10, rad: 1, start: 1, end: 2 }

      it 'creates a position entity for that place' do
        described_class.process_position_aggregate bob, bob_position

        expect(Entity.positions.count).to eql 1

        position_entity = Entity.positions.first

        expect(position_entity.type).to eql :position
        expect(position_entity.level).to eql :automatic
        expect(position_entity.name).not_to match /Position 51.50\d\, 0.11\d/
        expect(position_entity.path).to eql [bob.path.first]
      end

      it 'links the two target entities to the position entity' do
        described_class.process_position_aggregate bob, bob_position
        position_entity = Entity.positions.first

        expect(position_entity.linked_to? bob.reload).to be_true
        expect(position_entity.linked_to? alice.reload).to be_true
      end
    end

    context 'when a position entity already exists' do

      let!(:bob_position) { create_position_aggregate_for target_bob, lat: london_eye[0], lon: london_eye[1], rad: 10, start: midday, end: midday + 40.minutes }
      let!(:alice_position) { create_position_aggregate_for target_alice, lat: near_london_eye[0], lon: near_london_eye[1], rad: 12, start: midday, end: midday + 42.minutes }
      let!(:eve_position) { create_position_aggregate_for target_eve, lat: near_london_eye[0], lon: near_london_eye[1], rad: 15, start: midday, end: midday + 41.minutes }

      let!(:existing_position) do
        Entity.create! type: :position, path: [operation.id], position: london_eye.reverse, level: :automatic, name: 'London eye'
      end

      it 'does not create any new position entity' do
        expect {
          described_class.process_position_aggregate bob, bob_position
          described_class.process_position_aggregate alice, alice_position
        }.not_to change(Entity.positions, :count)
      end

      it 'links the two target entities to that position' do
        described_class.process_position_aggregate eve, eve_position

        existing_position.reload
        expect(existing_position.linked_to? bob.reload).to be_true
        expect(existing_position.linked_to? alice.reload).to be_true
        expect(existing_position.linked_to? eve.reload).to be_true
      end
    end
  end
end

end
end
