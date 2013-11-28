require 'spec_helper'

require_db 'db_layer'
require_db 'grid'

describe 'Given a person (entity)' do

  enable_license
  silence_alerts

  let(:operation) { factory_create(:operation) }

  let!(:person_entity) { factory_create(:person_entity, operation: operation, name: 'bob') }

  before {
    expect(Entity.all.count).to eq(1)
    expect(Item.all.count).to eq(1)
  }

  context 'when it is promoted to target (entity)' do

    before { person_entity.promote_to_target }

    let(:target) { Item.targets.first }

    it 'creates a target (item) with the same name belonging to the same op.' do
      expect(Item.all.count).to eq(2)

      expect(target.name).to eq(person_entity.name)
      expect(target.path).to eq([operation.id])
    end

    it 'it is promoted to target (entity) with the same name and a new valid path' do
      expect(Entity.all.count).to eq(1)

      entity = Entity.targets.first
      expect(entity.name).to eq(person_entity.name)
      expect(entity.path).to eq([operation.id, target.id])

      expect(entity.id).to eq(person_entity.id)
    end
  end

  describe 'linked to another entity' do

    let!(:another_entity) { factory_create(:person_entity, operation: operation, name: 'john') }

    before {
      factory_create(:entity_link, from: person_entity, to: another_entity)
    }

    context 'when it is promoted to target (entity)' do

      before { person_entity.promote_to_target }

      it 'does not lose its links' do
        expect(person_entity).to be_linked_to(another_entity.reload)
      end
    end
  end
end
