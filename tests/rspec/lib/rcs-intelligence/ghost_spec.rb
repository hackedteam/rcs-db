require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'link_manager'
require_intelligence 'ghost'

module RCS
module Intelligence

  describe Ghost do

    enable_license
    silence_alerts

    let!(:operation) { factory_create :operation }

    let!(:target) { factory_create :target, operation: operation }

    let!(:entity) { factory_create :target_entity, target: target}

    it 'should use the Tracer module' do
      described_class.should respond_to :trace
      subject.should respond_to :trace
    end

    describe '#create_and_link_entity' do

      context 'when the given addrebook evidence is invalid' do

        let(:evidence) { factory_create :addressbook_evidence, target: target, data:{'handle' => nil} }

        it 'does nothing' do
          RCS::DB::LinkManager.any_instance.should_not_receive :add_link
          described_class.create_and_link_entity entity, evidence
        end
      end


      context 'when the given addrebook evidence refers to the entity target' do

        let(:evidence) { factory_create :addressbook_evidence, target: target, data:{'type' => :target} }

        it 'does nothing' do
          RCS::DB::LinkManager.any_instance.should_not_receive :add_link
          described_class.create_and_link_entity entity, evidence
        end
      end

      context 'when there isn\'t another entity with the same handle' do

        let(:evidence) { factory_create :addressbook_evidence, target: target }

        it 'creates a ghost entity with the given handle' do
          RCS::DB::LinkManager.any_instance.stub :add_link
          described_class.create_and_link_entity entity, evidence
          ghost_entity = Entity.where(:id.ne => entity.id, :level => :ghost).first
          ghost_entity.name.should == 'John Snow'
          ghost_entity.handles.first.handle == 'j.snow'
          ghost_entity.handles.first.type == :skype
        end

        context 'when the given handle has a blank name' do

          let(:evidence) { factory_create :addressbook_evidence, target: target, data: {'name' => ''} }

          it 'creates a ghost entity whose name is the handle value' do
            RCS::DB::LinkManager.any_instance.stub :add_link
            described_class.create_and_link_entity entity, evidence
            ghost_entity = Entity.where(:id.ne => entity.id, :level => :ghost).first
            ghost_entity.name.should == 'j.snow'
          end
        end

        it 'creates a link from the entity to the new ghost entity' do
          described_class.create_and_link_entity entity, evidence
          ghost_entity = Entity.where(:id.ne => entity.id, :level => :ghost).first
          ghost_entity.linked_to?(entity.reload, type: :know).should be_true
        end
      end

      context 'when there is another entity with a matching handle' do

        let(:another_entity) { factory_create :person_entity, operation: operation, name: 'Jamie Lannister' }

        let(:evidence) { factory_create :addressbook_evidence, target: target, data: {program: :skype, handle: 'j.lann'} }

        before { another_entity.create_or_update_handle :skype, 'j.lann', 'The King Slayer' }

        it 'does not create any ghost entity' do
          RCS::DB::LinkManager.any_instance.stub :add_link
          described_class.create_and_link_entity entity, evidence
          Entity.where(:id.ne => entity.id, :level => :ghost).count.should be_zero
        end

        it 'creates a link from the entity to the other (the existing one)' do
          described_class.create_and_link_entity entity, evidence
          entity.linked_to?(another_entity.reload).should be_true
        end
      end
    end
  end

end
end
