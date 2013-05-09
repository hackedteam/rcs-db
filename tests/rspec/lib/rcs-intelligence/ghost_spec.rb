require 'spec_helper'
require_db 'db_layer'
require_db 'link_manager'
require_intelligence 'ghost'

module RCS
module Intelligence

  describe Ghost do

    use_db
    enable_license
    silence_alerts

    let!(:operation) { Item.create!(name: 'testoperation', _kind: 'operation', path: [], stat: ::Stat.new) }
    let!(:target) { Item.create!(name: 'testtarget', _kind: 'target', path: [operation._id], stat: ::Stat.new) }
    let!(:entity) { Entity.any_in({path: [target.id]}).first }

    it 'should use the Tracer module' do
      described_class.should respond_to :trace
      subject.should respond_to :trace
    end

    describe '#create_and_link_entity' do
      let(:handle_array) { ['Jamie Lannister', :skype, 'j.lann'] }

      context 'when the given handle is not an array' do

        it 'does nothing' do
          RCS::DB::LinkManager.any_instance.should_not_receive :add_link
          described_class.create_and_link_entity entity, 'a_string'
        end
      end


      context 'when there isn\'t another entity with the same handle' do

        it 'creates a ghost entity with the given handle' do
          RCS::DB::LinkManager.any_instance.stub :add_link
          described_class.create_and_link_entity entity, handle_array
          ghost_entity = Entity.where(:id.ne => entity.id, :level => :ghost).first
          ghost_entity.name.should == 'Jamie Lannister'
          ghost_entity.handles.first.handle == 'j.lann'
          ghost_entity.handles.first.type == :skype
        end

        it 'creates a link from the entity to the new ghost entity' do
          described_class.create_and_link_entity entity, handle_array
          ghost_entity = Entity.where(:id.ne => entity.id, :level => :ghost).first
          ghost_entity.linked_to?(entity).should be_true
        end
      end

      context 'when there is another entity with a matching handle' do

        let!(:another_entity) { Entity.create! path: [operation.id] }

        before { another_entity.create_or_update_handle handle_array[1], handle_array[2], 'The King Slayer' }

        it 'does not create any ghost entity' do
          RCS::DB::LinkManager.any_instance.stub :add_link
          described_class.create_and_link_entity entity, handle_array
          Entity.where(:id.ne => entity.id, :level => :ghost).count.should be_zero
        end


        it 'creates a link from the entity to the other (the existing one)' do
          described_class.create_and_link_entity entity, handle_array
          entity.linked_to?(another_entity.reload).should be_true
        end
      end
    end
  end

end
end
