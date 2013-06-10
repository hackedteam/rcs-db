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
  use_db
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

end
