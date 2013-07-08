require 'spec_helper'

require_db 'db_layer'
require_db 'grid'
require_aggregator 'processor'
require_intelligence 'processor'

describe 'there is a single target communicating frequently with a peer' do

  enable_license
  silence_alerts

  let!(:operation) { factory_create(:operation) }
  let(:target) { factory_create(:target, operation: operation) }
  let(:entity) { Entity.any_in({path: [target.id]}).first }
  let(:agent) { factory_create(:agent, target: target) }
  let(:handle) {'receiver'}

  before do
    RCS::Aggregator::Processor.stub(:check_intelligence_license).and_return true
  end

  # fill the queue with a frequent peer
  def fill_aggregator_queue(type)
    case type
      when :chat
        15.times do |day|
          data_in = {'from' => handle, 'rcpt' => 'sender', 'incoming' => 1, 'program' => 'skype', 'content' => 'test message'}
          evidence_in = Evidence.collection_class(target.id).create!(da: Time.now.to_i + day*86400, aid: agent.id, type: :chat, data: data_in)

          data_out = {'from' => 'sender', 'rcpt' => handle, 'incoming' => 0, 'program' => 'skype', 'content' => 'test message'}
          evidence_out = Evidence.collection_class(target.id).create!(da: Time.now.to_i + day*86400, aid: agent.id, type: :chat, data: data_out)

          AggregatorQueue.add target.id, evidence_in.id, evidence_in.type
          AggregatorQueue.add target.id, evidence_out.id, evidence_out.type
        end
      when :call
        15.times do |day|
          data_in = {'from' => handle, 'rcpt' => 'sender', 'incoming' => 1, 'program' => 'skype', 'content' => 'test message'}
          evidence_in = Evidence.collection_class(target.id).create!(da: Time.now.to_i + day*86400, aid: agent.id, type: :call, data: data_in)

          AggregatorQueue.add target.id, evidence_in.id, evidence_in.type
        end
    end
  end

  def process_aggregator_queue(type)
    begin
      entry, count = AggregatorQueue.get_queued([type])
      RCS::Aggregator::Processor.process entry
    end while count > 0
  end

  def process_intelligence_queue
    begin
      entry, count = IntelligenceQueue.get_queued
      RCS::Intelligence::Processor.process  entry
    end while count > 0
  end

  context 'fequencing chat messages' do

    it 'should create the frequent entity as :suggested if not present' do
      fill_aggregator_queue :chat
      process_aggregator_queue :chat

      newly_created_entity = Entity.where(name: 'receiver').first

      newly_created_entity.should_not be_nil
      newly_created_entity.level.should be :suggested

      new_handle = newly_created_entity.handles.first
      new_handle.type.should eq :skype
      new_handle.handle.should eq handle

      newly_created_entity.links.size.should be 1
      newly_created_entity.links.first.le.should eq entity.id
    end

    it 'should not create a new entity if already present' do
      new_entity = Entity.create!(name: handle, type: :person, level: :automatic, path: [entity.path.first])
      new_entity.create_or_update_handle(:skype, handle)

      entity_count = Entity.count

      fill_aggregator_queue :chat
      process_aggregator_queue :chat
      process_intelligence_queue

      Entity.count.should be entity_count
      new_entity.reload
      new_entity.links.size.should be 1
      new_entity.links.first.le.should eq entity.id
      new_entity.links.first.level.should be :automatic
    end

    it 'should promote old entity if already present and ghost' do
      new_entity = Entity.create!(name: handle, type: :person, level: :ghost, path: [entity.path.first])
      new_entity.create_or_update_handle(:skype, handle)
      RCS::DB::LinkManager.instance.add_link from: entity, to: new_entity, level: :ghost, type: :know, versus: :out

      entity_count = Entity.count

      fill_aggregator_queue :chat
      process_aggregator_queue :chat
      process_intelligence_queue

      Entity.count.should be entity_count
      new_entity.reload
      new_entity.level.should be :suggested
      new_entity.links.size.should be 1
      new_entity.links.first.le.should eq entity.id
      new_entity.links.first.level.should be :automatic
    end

  end

  context 'frequencing call messages' do

    it 'should create the frequent entity' do
      fill_aggregator_queue :call
      process_aggregator_queue :call

      newly_created_entity = Entity.where(name: 'receiver').first

      newly_created_entity.should_not be_nil
      newly_created_entity.level.should be :suggested

      new_handle = newly_created_entity.handles.first
      new_handle.type.should eq :skype
      new_handle.handle.should eq handle

      newly_created_entity.links.size.should be 1
      newly_created_entity.links.first.le.should eq entity.id
    end

  end
end

