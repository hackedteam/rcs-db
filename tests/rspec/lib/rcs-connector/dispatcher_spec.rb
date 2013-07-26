require 'spec_helper'
require 'xmlsimple'
require_db 'db_layer'
require_db 'connector_manager'
require_db 'grid'
require_connector 'dispatcher'

describe RCS::Connector::Dispatcher do

  silence_alerts
  stub_temp_folder
  enable_license

  describe '#status_message' do

    it 'has a default value' do
      expect(described_class.status_message).to eq 'Idle'
    end
  end

  describe '#dispatch' do
  end

  describe '#dump' do

    let(:operation) { factory_create :operation }

    let(:target) { factory_create :target, operation: operation }

    let(:agent) { factory_create :agent, target: target }

    context 'given a MIC evidence' do

      let(:evidence) { factory_create :mic_evidence, agent: agent, target: target }

      let(:connector) { factory_create :connector, item: target, dest: spec_temp_folder }

      let(:expeted_dest_path) do
        File.join(spec_temp_folder, "#{operation.name}-#{operation.id}", "#{target.name}-#{target.id}", "#{agent.name}-#{agent.id}")
      end

      context 'when the connector type is JSON' do

        before { described_class.dump(evidence, connector) }

        it 'creates a json file' do
          path = File.join(expeted_dest_path, "#{evidence.id}.json")
          expect { JSON.parse(File.read(path)) }.not_to raise_error
        end

        it 'does not create an xml file' do
          path = File.join(expeted_dest_path, "#{evidence.id}.xml")
          expect(File.exists?(path)).to be_false
        end

        it 'creates a binary file with the content of the mic registration' do
          path = File.join(expeted_dest_path, "#{evidence.id}.bin")
          expect(File.read(path)).to eql File.read(fixtures_path('audio.001.mp3'))
        end
      end

      context 'when the connector type is XML' do

        before do
          connector.update_attributes format: :xml
          described_class.dump(evidence, connector)
        end

        it 'does not create a json file' do
          path = File.join(expeted_dest_path, "#{evidence.id}.json")
          expect(File.exists?(path)).to be_false
        end

        it 'creates an xml file' do
          path = File.join(expeted_dest_path, "#{evidence.id}.xml")
          xml_str = File.read(path)
          expect { XmlSimple.xml_in(xml_str) }.not_to raise_error
        end
      end
    end
  end
end
