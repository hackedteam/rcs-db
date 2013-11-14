require 'spec_helper'

require_db 'db_layer'
require_db 'grid'
require_aggregator 'processor'
require_intelligence 'processor'

describe 'The HandleBook' do

  enable_license
  silence_alerts

  let(:operation) { factory_create(:operation) }

  let(:target) { factory_create(:target, operation: operation, name: "bob") }

  let(:entity) { factory_create(:target_entity, target: target) }

  let(:agent) { factory_create(:agent, target: target) }

  context 'a chat evidence is created and processed by the Aggregator module' do

    let!(:chat_evidence) { factory_create(:chat_evidence, target: target, agent: agent, data: {'from' => 'bob', 'rcpt' => 'alice', 'incoming' => 0, 'program' => :skype}) }

    before do
      expect(Item.count).to eq(3)
      expect(Evidence.target(target).count).to eq(1)
      expect(Aggregate.target(target).count).to eq(0)

      chat_evidence.add_to_aggregator_queue
      RCS::Aggregator::Processor.process AggregatorQueue.get_queued([:chat]).first
    end

    it 'creates a record in the handle book' do
      expect(HandleBook.targets(:skype, 'alice')).to eq([target.id])
    end

    it 'has not created any links or handles on the entity' do
      expect(entity.handles.count).to eq(0)
      expect(entity.links.count).to eq(0)
    end

    context 'than is processed by the Intelligence module' do

      before do
        RCS::Intelligence::Processor.process IntelligenceQueue.get_queued.first
      end

      it 'creates an handle on the entity' do
        expect(entity.handles.count).to eq(1)
        expect(entity.handles[0].handle).to eq('bob')
      end

      it 'has not created any other entities' do
        expect(Entity.count).to eq(1)
      end

      it 'has not created any links' do
        expect(entity.links.count).to eq(0)
      end
    end
  end
end
