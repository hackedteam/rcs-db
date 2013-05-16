require 'spec_helper'

require 'spec_helper'
require_db 'db_layer'
require_aggregator 'processor'
require_intelligence 'processor'


describe 'There are two entities in the same operation' do

  use_db
  enable_license
  silence_alerts

  # There is one operation

  let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

  # The first target (with its entity) and an agent

  let(:target) { Item.create!(name: 'testtarget', _kind: :target, path: [operation.id], stat: ::Stat.new) }

  let(:entity) { Entity.any_in({path: [target.id]}).first }

  let(:aggregate_class) { Aggregate.target target.id }

  let(:agent) { Item.create!(name: 'testagent', _kind: :agent, path: target.path+[target.id], stat: ::Stat.new) }

  # Another target (with its entity)

  let(:another_target) { Item.create!(name: 'testtarget2', _kind: :target, path: [operation.id], stat: ::Stat.new) }

  let(:another_entity) { Entity.any_in({path: [another_target.id]}).first }

  # Add an handle to the other entity

  before { another_entity.create_or_update_handle "skype", "john", "John Cipollina" }

  describe 'an evidence is sended to the aggregator' do

    let(:chat_data) { {'from' => 'john', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'all your base are belong to us'} }

    let(:chat_evidence) { Evidence.collection_class(target.id).create!(da: Time.now.to_i, aid: agent.id, type: :chat, data: chat_data) }

    before { AggregatorQueue.add target.id, chat_evidence.id, chat_evidence.type }

    it 'links the two entities' do
      RCS::Aggregator::Processor.process AggregatorQueue.get_queued.first
      RCS::Intelligence::Processor.process IntelligenceQueue.get_queued.first

      entity.reload
      another_entity.reload

      entity.linked_to?(another_entity).should be_true
    end
  end

  describe 'an evidence (without versus) is sended to the aggregator' do

    let(:chat_data) { {'peer' => 'john', 'program' => 'skype', 'content' => 'my kingdom for a horse'} }

    let(:chat_evidence) { Evidence.collection_class(target.id).create!(da: Time.now.to_i, aid: agent.id, type: :chat, data: chat_data) }

    before { AggregatorQueue.add target.id, chat_evidence.id, chat_evidence.type }

    it 'links the two entities' do
      RCS::Aggregator::Processor.process AggregatorQueue.get_queued.first
      RCS::Intelligence::Processor.process IntelligenceQueue.get_queued.first

      entity.reload
      another_entity.reload

      entity.linked_to?(another_entity).should be_true
    end
  end

end
