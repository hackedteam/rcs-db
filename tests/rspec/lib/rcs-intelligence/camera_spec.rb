require 'spec_helper'
require_db 'db_layer'
require_intelligence 'camera'

module RCS
module Intelligence

  describe Camera do
    let(:entity_with_photos) { Entity.new(photos: ["filename"]) }
    let(:empty_evidence) { Evidence.dynamic_new('testtarget') }

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
        pending
      end
    end
  end

end
end
