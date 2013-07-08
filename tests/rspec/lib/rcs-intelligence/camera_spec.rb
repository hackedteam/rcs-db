require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'camera'

module RCS
module Intelligence

  describe Camera do

    silence_alerts

    let(:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }
    let(:target) { Item.create!(name: 'test-target', _kind: 'target', path: [operation._id], stat: ::Stat.new) }
    let(:agent) { Item.create!(name: 'test-agent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }
    let(:entity_with_photos) { Entity.new(photos: ["filename"]) }
    let(:empty_evidence) { Evidence.dynamic_new('testtarget') }
    let :camera_evidence do
      id = RCS::DB::GridFS.put("photo_binary_data", {filename: 'photo_filename'}, target._id.to_s)
      data = {'_grid' => id, '_grid_size' => 6}
      Evidence.collection_class(target._id).create!(da: Time.now.to_i, aid: agent._id, type: 'camera', data: data)
    end
    # This entity is automatically created when an Item of kind TARGET is saved
    let(:entity_without_photos) { Entity.any_in({path: [target._id]}).first }

    it 'should use the Tracer module' do
      described_class.should respond_to :trace
      subject.should respond_to :trace
    end

    context '#save_first_camera' do
      context 'when a photo has been associated to the entity' do
        it 'should return without adding the new photo' do
          entity_with_photos.should_not_receive :add_photo
          described_class.save_first_camera entity_with_photos, empty_evidence
        end
      end

      context 'when the entity has no photos' do
        before do
          camera_evidence
          entity_without_photos.photos.should be_empty
        end

        it 'should save the new photo' do
          described_class.save_first_camera entity_without_photos, camera_evidence
          entity_without_photos.photos.should_not be_empty
        end
      end
    end
  end

end
end
