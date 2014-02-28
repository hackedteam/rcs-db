require 'spec_helper'

require_db 'db_layer'
require_db 'grid'
require_aggregator 'processor'
require_intelligence 'processor'

describe 'Two targets (in different ops) communicate with the same peer' do

  enable_license
  silence_alerts

  # The first operation with target bob

  let(:operation) { factory_create(:operation) }

  let(:target) { factory_create(:target, operation: operation, name: "bob") }

  let(:entity) { factory_create(:target_entity, target: target) }

  let(:agent) { factory_create(:agent, target: target) }

  # The second operation with target john

  let(:operation2) { factory_create(:operation) }

  let(:target2) { factory_create(:target, operation: operation2, name: "john") }

  let(:entity2) { factory_create(:target_entity, target: target2) }

  let(:agent2) { factory_create(:agent, target: target2) }


  context 'a chat evidence is created for each target and processed by the Aggregator module' do

    let!(:chat_evidence) { factory_create(:chat_evidence, target: target, agent: agent, data: {'from' => 'bob', 'rcpt' => 'alice', 'incoming' => 0, 'program' => :sms}) }

    let!(:chat_evidence2) { factory_create(:chat_evidence, target: target2, agent: agent2, data: {'from' => 'john', 'rcpt' => 'alice', 'incoming' => 0, 'program' => :mms}) }

    before do
      expect(Item.count).to eq(6)

      [target, target2].each { |t|
        expect(Evidence.target(t).count).to eq(1)
        expect(Aggregate.target(t).count).to eq(0)
      }

      chat_evidence.add_to_aggregator_queue
      chat_evidence2.add_to_aggregator_queue

      RCS::Aggregator::Processor.process AggregatorQueue.get_queued([:chat]).first
      RCS::Aggregator::Processor.process AggregatorQueue.get_queued([:chat]).first
    end

    it 'creates a record in the handle book' do
      expect(HandleBook.count).to eq(1)
      expect(HandleBook.targets_that_communicate_with(:phone, 'alice')).to eq([target, target2])
    end

    it 'has not created any links or handles on the entity' do
      expect(entity.handles.count).to eq(0)
      expect(entity.links.count).to eq(0)
    end

    context 'than is processed by the Intelligence module' do

      before do
        RCS::Intelligence::Processor.process IntelligenceQueue.get_queued.first
        RCS::Intelligence::Processor.process IntelligenceQueue.get_queued.first
      end

      it 'creates an handle on each entities' do
        expect(entity.handles.count).to eq(1)
        expect(entity.handles[0].handle).to eq('bob')
        expect(entity.handles[0].type).to eq(:phone)

        expect(entity2.handles.count).to eq(1)
        expect(entity2.handles[0].handle).to eq('john')
        expect(entity2.handles[0].type).to eq(:phone)
      end

      it 'creates two group entities' do
        expect(Entity.groups.count).to eq(2)
      end

      it 'creates a third entity (that represent the common peer) properly linked' do
        expect(Entity.targets.count).to eq(2)
        expect(Entity.persons.count).to eq(1)

        person = Entity.persons.first

        expect(person.name).to eq("alice")
        expect(person.path).to eq([operation.id])

        expect(entity).to be_linked_to(person)
        expect(entity2).to be_linked_to(person)

        expect(entity).not_to be_linked_to(entity2)
      end
    end
  end
end
