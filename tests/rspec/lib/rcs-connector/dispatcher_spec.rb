require 'spec_helper'
require 'xmlsimple'
require_db 'db_layer'
require_db 'connectors'
require_db 'grid'
require_connector 'dispatcher'

describe RCS::Connector::Dispatcher do

  use_db
  silence_alerts
  stub_temp_folder
  enable_license

  describe '#status_message' do

    it 'has a default value' do
      expect(described_class.status_message).to eq 'Unknown'
    end
  end

  describe '#dispatch' do

    it 'changes the stasus message to idle' do
      expect { described_class.dispatch }.to change(described_class, :status_message).to('Idle')
    end

    context "when an error occurs" do

      before { described_class.stub(:can_dispatch?).and_raise("unexpected error") }

      it 'changes the stasus message to error' do
        expect {
          described_class.dispatch rescue nil
        }.to change(described_class, :status_message).to('Error')
      end

      it 'raises the error' do
        expect { described_class.dispatch }.to raise_error(/unexpected error/)
      end
    end

    context 'when the connector queue is empty' do

      it 'does nothing' do
        described_class.should_not_receive :process
        described_class.dispatch
      end
    end

    context 'when the connector queue is not empty' do

      let!(:connector_queue) { factory_create(:connector_queue) }

      it 'calls #process' do
        described_class.should_receive :process
        described_class.dispatch
      end
    end

    context 'when the license is invalid' do

      before { described_class.stub(:can_dispatch?).and_return(false) }

      it 'changes the stasus message to "license needed"' do
        expect { described_class.dispatch }.to change(described_class, :status_message).to('License needed')
      end

      it 'does nothing' do
        described_class.should_not_receive :process
        described_class.dispatch
      end
    end
  end

  describe '#process' do

    let!(:connector_queue) { factory_create(:connector_queue) }

    let(:evidence) { ::Evidence.collection_class(connector_queue.tg_id).find(connector_queue.ev_id) }

    before { described_class.stub(:dump) }

    it 'calls #dump' do
      described_class.should_receive :dump
      described_class.process connector_queue
    end

    context 'when the evidence should be keeped' do

      before { RCS::DB::Connectors.stub(:discard_evidence?).and_return(false) }

      it 'keeps the evidence' do
        described_class.process connector_queue
        expect{ evidence.reload }.not_to raise_error
      end
    end

    context 'when the evidence should be deleted' do

      before { RCS::DB::Connectors.stub(:discard_evidence?).and_return(true) }

      it 'deletes the evidence' do
        described_class.process connector_queue
        expect{ evidence.reload }.to raise_error(Mongoid::Errors::DocumentNotFound)
      end
    end
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
          connector.update_attributes type: 'XML'
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
