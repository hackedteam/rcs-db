require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'accounts'

module RCS
module Intelligence

  describe Accounts do

    use_db
    enable_license
    silence_alerts

    let(:operation) { factory_create :operation }

    let(:target) { factory_create :target, operation: operation }

    let(:agent) { factory_create :agent, target: target }

    let(:entity) { factory_create :target_entity, target: target }

    let(:known_program) { subject.known_services.sample }

    it 'should use the Tracer module' do
      subject.should respond_to :trace
      subject.should respond_to :trace
    end

    describe '#add_handle' do

      let(:evidence) do
        factory_create :addressbook_evidence, agent: agent, data: {'type' => :target, 'program' => known_program, 'handle' => 'j.snow', 'name' => 'John Snow'}
      end

      it 'adds an handle to the given entity' do
        subject.add_handle entity, evidence
        entity.reload
        expect(entity.handles).not_to be_empty
      end

      context 'when the target has an handle' do

        before { entity.create_or_update_handle known_program, 'j.snow' }

        it 'updates the existing handle' do
          subject.add_handle entity, evidence
          entity.reload
          expect(entity.handles.size).to eql 1
          expect(entity.handles.first.name).to eql 'John Snow'
        end
      end

      context 'when the evidence is not valid' do

        # Is invalid because the 'handle' key is missing in the data hash.
        let(:invalid_evidence) do
          factory_create :addressbook_evidence, agent: agent, data: {'type' => :target, 'program' => known_program, 'handle' => nil}
        end

        it 'does not add any handles' do
          subject.add_handle entity, invalid_evidence
          expect(entity.handles).to be_empty
        end
      end

      describe '#valid_addressbook_evidence?' do

        it 'returns false when the given evidence is not valid' do
          evidence = factory_create :addressbook_evidence, agent: agent, data: {'type' => :not_target, 'program' => known_program, 'handle' => nil}
          expect(subject.valid_addressbook_evidence?(evidence)).to be_false

          evidence = factory_create :addressbook_evidence, agent: agent, data: {'program' => :my_program}
          expect(subject.valid_addressbook_evidence?(evidence)).to be_false

          evidence = factory_create :addressbook_evidence, agent: agent, data:{'type' => :not_target_or_invalid}
          expect(subject.valid_addressbook_evidence?(evidence)).to be_true
        end

        it 'returns true when the given evidence is valid' do
          evidence = factory_create :addressbook_evidence, agent: agent
          expect(subject.valid_addressbook_evidence?(evidence)).to be_true
        end
      end
    end

    describe '#handle_attributes' do

      context 'when the evidence is not valid' do
        let(:evidence) { factory_create :addressbook_evidence, agent: agent, data: {'type' => :target, 'program' => :asdasd, 'handle' => 'JoHn.SnOw', 'name' => 'John Snow'} }
        it ('returns nil') { expect(subject.handle_attributes(evidence)).to be_nil }
      end

      context 'when the evidence is valid' do
        let(:expectd_result) { {name: 'John Snow', type: :skype, handle: 'j.snow'} }
        let(:evidence) {  factory_create :addressbook_evidence, agent: agent }

        it 'returns an array with name, program and handle' do
          expect(subject.handle_attributes(evidence)).to eql expectd_result
        end
      end

      context 'when the evidence has an empty name' do
        let(:evidence) {  factory_create :addressbook_evidence, agent: agent, data: {'name' => ''} }

        it 'uses the handle value for the name' do
          result = subject.handle_attributes(evidence)
          expect(result[:name]).to eql result[:handle]
        end
      end
    end

    describe '#update_person_entity_name' do

      let(:evidence) { factory_create :addressbook_evidence, agent: agent }

      context 'when there is an entity person with a blank name' do

        let!(:existing_entity) { factory_create :person_entity, operation: operation, name: '' }

        it 'does not update the person entity name' do
          subject.update_person_entity_name entity, evidence
          expect(existing_entity.reload.name).to eql ''
        end
      end

      context 'when there is an entity person whose name is the evidence\'s handle' do

        let!(:existing_entity) { factory_create :person_entity, operation: operation, name: 'j.snow' }

        it 'updates the person entity name' do
          subject.update_person_entity_name entity, evidence
          expect(existing_entity.reload.name).to eql 'John Snow'
        end

        context 'and the evidence\'s handle name is blank' do

          let(:evidence) { factory_create :addressbook_evidence, agent: agent, data: {'name' => ''} }

          it 'does not updates the person entity name' do
            subject.update_person_entity_name entity, evidence
            expect(existing_entity.reload.name).to eql 'j.snow'
          end
        end
      end

      context 'when there is an entity person with a human readable name' do

        let!(:existing_entity) { factory_create :person_entity, operation: operation, name: 'Bob' }

        it 'does not updates the person entity name' do
          subject.update_person_entity_name entity, evidence
          expect(existing_entity.reload.name).to eql 'Bob'
        end
      end
    end
  end

end
end
