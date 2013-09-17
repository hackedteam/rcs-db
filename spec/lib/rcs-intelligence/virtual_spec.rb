require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'virtual'

module RCS
module Intelligence

  describe Virtual do

    enable_license
    silence_alerts

    let(:operation) { Item.create!(name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new) }

    let(:target_entity) do
      target = Item.create!(name: 'bob', _kind: 'target', path: [operation._id], stat: ::Stat.new)
      Entity.any_in({path: [target._id]}).first
    end

    def virtual_entity name, url
      entity = Entity.create!(name: name, type: :virtual, level: :automatic, path: [operation._id])
      [url].flatten.each { |u| entity.create_or_update_handle(:url, u) }
      entity
    end

    it 'should use the Tracer module' do
      subject.should respond_to :trace
    end

    describe '#find_virtual_entity_by_url' do

      context 'when the aren\'t any virtual entities' do

        it 'returns nil' do
          expect(subject.find_virtual_entity_by_url('an_url')).to be_nil
        end
      end

      context 'when there is a virtual entity but with a different url' do

        before { virtual_entity("reddit", "http://reddit.com/r/gaming") }

        it 'returns nil' do
          expect(subject.find_virtual_entity_by_url('an_url')).to be_nil
        end
      end

      context 'when there is a virtual entity that can be founded' do

        let!(:entity) { virtual_entity("reddit", ["http://reddit.com/r/gif", "http://reddit.com/r/gaming"]) }

        it 'returns that entity' do
          expect(subject.find_virtual_entity_by_url('http://reddit.com/r/gaming')).to eql entity
        end
      end
    end

    describe '#process_url_evidence' do

      let(:url_evidence) do
        Evidence.dynamic_new('bob').tap do |e|
          e.data = {'url' => 'http://it.wikipedia.org/wiki/Tim_Berners-Lee'}
          e.type = :url
        end
      end

      let(:another_url_evidence) do
        Evidence.dynamic_new('bob').tap do |e|
          e.data = {'url' => 'http://it.wikipedia.org/wiki/Computing'}
          e.type = :url
        end
      end

      context 'when there isn\'t any matching virtual entity' do

        let!(:entity) { virtual_entity("4chan", "http://4chan.org/terrorism") }

        it 'does not create any link' do
          subject.process_url_evidence target_entity, url_evidence
          expect(target_entity.reload).not_to be_linked_to entity.reload
        end
      end

      context 'when there is a matching virtual entity' do

        let!(:entity) { virtual_entity("wikipedia", ["http://it.wikipedia.org/wiki/Tim_Berners-Lee", 'http://it.wikipedia.org/wiki/Computing']) }

        it 'creates a virtual link' do
          subject.process_url_evidence target_entity, url_evidence
          subject.process_url_evidence target_entity, another_url_evidence
          link = target_entity.links.first

          expect(target_entity.reload).to be_linked_to entity.reload
          expect(target_entity.links.size).to eql 1
          expect(link.type).to eql :virtual
          expect(link.info).to eql ['http://it.wikipedia.org/wiki/Tim_Berners-Lee', 'http://it.wikipedia.org/wiki/Computing']
        end
      end
    end
  end

end
end
