require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'camera'

describe RCS::Intelligence::Camera do

  silence_alerts

  let(:operation) { factory_create(:operation) }

  let(:target) { factory_create(:target, operation: operation) }

  let(:agent) { factory_create(:agent, target: target) }

  let(:empty_evidence) { factory_create(:chat_evidence, target: target, agent: agent) }

  let(:camera_evidence) { factory_create(:screenshot_evidence, target: target, agent: agent, type: 'camera', data: {'face' => true}) }

  it 'should use the Tracer module' do
    described_class.should respond_to :trace
    subject.should respond_to :trace
  end

  context '#save_first_camera' do

    let(:entity_with_photos) { factory_create(:target_entity, target: target, photos: ["filename"]) }

    context 'when the camera evidence does not contains a photo with a face' do
      before do
        camera_evidence.data['fate'] = false
        camera_evidence.save!
      end

      it 'does nothing' do
        expect(described_class.save_picture(entity_with_photos, empty_evidence)).to be_nil
      end
    end

    context 'when a photo has been associated to the entity' do
      it 'should return without adding the new photo' do
        entity_with_photos.should_not_receive :add_photo
        described_class.save_picture entity_with_photos, empty_evidence
      end
    end

    context 'when the entity has no photos' do

      let(:entity_without_photos) { factory_create(:target_entity, target: target) }

      before do
        expect(entity_without_photos.photos).to be_empty
      end

      it 'should save the new photo' do
        described_class.save_picture(entity_without_photos, camera_evidence)
        expect(entity_without_photos.photos).not_to be_empty
      end
    end
  end
end
