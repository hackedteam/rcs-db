require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe Stat do
  context 'when initialized without any parameters' do

    it 'assigns a default value to some attributes' do
      expect(subject.size).to eql 0
      expect(subject.grid_size).to eql 0
      expect(subject.evidence).to eql Hash.new
      expect(subject.dashboard).to eql Hash.new
    end
  end
end

describe Item do
  silence_alerts
  enable_license

  it 'uses the RCS::Tracer module' do
    expect(described_class).to respond_to :trace
    expect(subject).to respond_to :trace
  end

  context 'when initialized without any parameters' do

    it 'assigns a default value to some attributes' do
      expect(subject.deleted).to be_false
      expect(subject.demo).to be_false
      expect(subject.scout).to be_false
      expect(subject.upgradable).to be_false
      expect(subject.purge).to eql [0, 0]
      expect(subject.good).to be_true
    end
  end

  it 'embeds one Stat' do
    expect(subject).to respond_to :stat
  end

  context 'when creating a target' do

    let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }
    let!(:target) { Item.create!(name: 'testtarget', _kind: :target, path: [operation.id], stat: ::Stat.new) }
    let (:aggregate_name) { "aggregate.#{target.id}" }
    let (:evidence_name) { "evidence.#{target.id}" }
    let (:grid_chunks_name) { RCS::DB::GridFS.collection_name(target.id) + '.chunks' }
    let (:grid_files_name) { RCS::DB::GridFS.collection_name(target.id) + '.files' }

    it 'should create the associated entity' do
      entity = Entity.where(name: target.name).first
      expect(entity).not_to be_nil
      expect(entity.path).to eq target.path + [target.id]
    end

    it 'should create sharded aggregate collection' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).to include aggregate_name
      coll = db.collection(aggregate_name)
      expect(coll.stats['sharded']).to be true
    end

    it 'should create sharded evidence collection' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).to include evidence_name
      coll = db.collection(evidence_name)
      expect(coll.stats['sharded']).to be true
    end

    it 'should create sharded grid collection for chunks' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).to include grid_chunks_name
      coll_chunks = db.collection(grid_chunks_name)
      expect(coll_chunks.stats['sharded']).to be true
    end

    it 'should not create sharded grid collection for files' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).to include grid_files_name
      coll_files = db.collection(grid_files_name)
      expect(coll_files.stats['sharded']).to be false
    end

  end

  context 'when destroying a target' do
    let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }
    let!(:target) { Item.create!(name: 'testtarget', _kind: :target, path: [operation.id], stat: ::Stat.new) }
    let!(:agent) { Item.create!(name: 'testagent', _kind: :agent, path: target.path + [target.id], stat: ::Stat.new) }

    let (:aggregate_name) { "aggregate.#{target.id}" }
    let (:evidence_name) { "evidence.#{target.id}" }
    let (:grid_chunks_name) { RCS::DB::GridFS.collection_name(target.id) + '.chunks' }
    let (:grid_files_name) { RCS::DB::GridFS.collection_name(target.id) + '.files' }

    before do
      target.destroy
    end

    it 'should delete the associated entity' do
      entity = Entity.where(name: target.name).first
      expect(entity).to be_nil
    end

    it 'should delete all its agents' do
      agent = Item.where(name: 'testagent').first
      expect(agent).to be_nil
    end

    it 'should delete the aggregate collection' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).not_to include aggregate_name
    end

    it 'should delete the evidence collection' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).not_to include evidence_name
    end

    it 'should delete the grid collection' do
      db = RCS::DB::DB.instance.mongo_connection
      expect(db.collection_names).not_to include grid_chunks_name
      expect(db.collection_names).not_to include grid_files_name
    end
  end

  describe '#restat' do

    context 'when the item is of type agent' do

      let!(:target) { factory_create(:agent) }

      let!(:agent_1) { factory_create(:agent, target: target) }

      let!(:agent_2) { factory_create(:agent, target: target) }

      let(:evidence_klass) { Evidence.target(target) }

      # Creates an evidence for the agent_1
      before { factory_create(:chat_evidence, agent: agent_1) }

      # An agent with empty stat should have been created
      before do
        expect(agent_1.stat.attributes.except('_id')).to eql Stat.new.attributes.except('_id')
      end

      it 'adds the count of all the evidences grouped by type' do
        agent_1.restat

        expect(agent_1.stat['evidence']['chat']).to eql 1
        expect(agent_1.stat['evidence']).to eq evidence_klass.count_by_type(aid: agent_1.id.to_s)
      end
    end
  end

  describe '#move_target' do

    # First operation

    let!(:operation) { factory_create(:operation) }
    let!(:target) { factory_create(:target, operation: operation) }
    let!(:target2) { factory_create(:target, operation: operation) }

    let!(:agent1) { factory_create(:agent, target: target) }

    let!(:connector1) { factory_create(:connector, item: target) }
    let!(:connector2) { factory_create(:connector, item: operation) }
    let!(:connector3) { factory_create(:connector, item: agent1) }

    let!(:entity1) { factory_create(:target_entity, target: target, name: 'bob') }
    let!(:entity2) { factory_create(:target_entity, target: target2, name: 'eve') }


    # Other operation

    let!(:other_operation) { factory_create(:operation) }
    let!(:other_target) { factory_create(:target, operation: other_operation) }
    let!(:other_entity) { factory_create(:target_entity, target: other_target, name: 'alice') }

    before do
      factory_create(:entity_handle, entity: entity1, name: 'bob', type: 'skype', handle: 'call-bob')
      factory_create(:entity_handle, entity: other_entity, name: 'alice', type: 'skype', handle: 'call-alice')
      factory_create(:aggregate, target: other_target, type: 'skype', data: {peer: 'call-bob', versus: :out, sender: 'call-alice'} )

      2.times { factory_create(:position_aggregate, target: target) }

      factory_create(:entity_link, from: entity1, to: entity2)
      target.move_target(other_operation)

      [target, target2, agent1, connector1, connector2, connector3, entity1, entity2, other_entity].each(&:reload)
    end

    context 'the original operation' do

      it 'does not contains the target and its factories and agents' do
        expect(Item.targets.path_include(operation).to_a).to eq([target2])
        expect(Item.agents.path_include(operation)).to be_empty
        expect(Item.factories.path_include(operation)).to be_empty
      end

      it 'does not contains the target entity anymore' do
        expect(Entity.path_include(operation).to_a).to eq([entity2])
      end
    end

    context 'the other operation' do

      it 'contains the moved target and its agents and/or factories' do
        expect(Item.targets.path_include(other_operation).first).to eq(target)
        expect(Item.agents.path_include(other_operation)).not_to be_empty
      end
    end

    context 'the moved items' do

      it 'has a valid checksum' do
        expect(target.cs).to eq(target.calculate_checksum)
        expect(agent1.cs).to eq(agent1.calculate_checksum)
      end
    end

    context 'the connectors on the target, agents and factories' do

      it 'are moved (path updated)' do
        expect(connector1.path).to eq([other_operation.id, target.id])
        expect(connector3.path).to eq([other_operation.id, target.id, agent1.id])
      end
    end

    context 'the other connectors' do

      it 'are not moved (path is not updated)' do
        expect(connector2.path).to eq([operation.id])
      end
    end

    context 'target entities' do

      it 'are moved (path updated)' do
        expect(Entity.targets.path_include(other_operation)).not_to be_empty
      end

      describe 'links' do

        it 'are recreated to match the new entities' do
          expect(entity1).not_to be_linked_to(entity2)
          expect(entity1).to be_linked_to(other_entity)
        end
      end

      describe 'postion aggregates' do

        it 'are resubmitted to the intelligence queue' do
          expect(IntelligenceQueue.count).to eq(2)
        end
      end
    end
  end
end
