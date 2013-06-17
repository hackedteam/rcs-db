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

    let(:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }

    let(:target) { Item.create!(name: 'test-target', _kind: 'target', path: [operation._id], stat: ::Stat.new) }

    let(:agent) { Item.create!(name: 'test-agent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }

    let(:entity) { Entity.any_in({path: [target._id]}).first }

    let(:known_program) { subject.known_services.sample }

    def addressbook_evidence data
      attributes = {da: Time.now.to_i, aid: agent._id, type: 'addressbook', data: data}
      Evidence.collection_class(entity.target_id).create! attributes
    end

    it 'should use the Tracer module' do
      subject.should respond_to :trace
      subject.should respond_to :trace
    end

    describe '#add_handle' do

      let(:evidence) { addressbook_evidence 'type' => :target, 'program' => known_program, 'handle' => 'j.snow', 'name' => 'John Snow' }

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
        let(:invalid_evidence) { addressbook_evidence 'type' => :target, 'program' => known_program }

        it 'does not add any handles' do
          subject.add_handle entity, invalid_evidence
          expect(entity.handles).to be_empty
        end
      end

      describe '#valid_addressbook_evidence?' do

        it 'returns false when the given evidence is not valid' do
          evidence = addressbook_evidence 'type' => :not_target, 'program' => known_program
          expect(subject.valid_addressbook_evidence?(evidence)).to be_false

          evidence = addressbook_evidence 'type' => :target, 'program' => :my_program, 'handle' => 'john@asd.com'
          expect(subject.valid_addressbook_evidence?(evidence)).to be_false

          evidence = addressbook_evidence 'type' => :not_target, 'program' => known_program, 'handle' => 'john@asd.com'
          expect(subject.valid_addressbook_evidence?(evidence)).to be_true
        end

        it 'returns true when the given evidence is valid' do
          evidence = addressbook_evidence 'type' => :target, 'program' => known_program, 'handle' => 'john@asd.com'
          expect(subject.valid_addressbook_evidence?(evidence)).to be_true
        end
      end
    end

    describe '#handle_attributes' do

      context 'when the evidence is not valid' do
        let(:evidence) { addressbook_evidence('type' => :target, 'program' => :asdasd, 'handle' => 'JoHn.SnOw', 'name' => 'John Snow') }
        it ('returns nil') { expect(subject.handle_attributes(evidence)).to be_nil }
      end

      context 'when the evidence is valid' do
        let(:expectd_result) { {name: 'John Snow', type: :skype, handle: 'john.snow'} }
        let(:evidence) { addressbook_evidence('type' => :target, 'program' => :skype, 'handle' => 'JoHn.SnOw', 'name' => 'John Snow') }

        it 'returns an array with name, program and handle' do
          expect(subject.handle_attributes(evidence)).to eql expectd_result
        end
      end
    end
  end

end
end
