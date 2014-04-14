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

  let(:subject) { described_class }

  describe '#run' do

    before { subject.stub(:loop_and_wait).and_yield }

    context 'when there are 3 connector_queue with the same scope' do

      before do
        3.times { factory_create(:connector_queue_for_evidence) }
      end

      it 'calls dispatch once (create one thread)' do
        subject.should_receive(:dispatch).once
        subject.run
      end
    end

    context 'when it starts one or more thread' do
      before do
        factory_create(:connector_queue_for_evidence)
        subject.stub(:dispatch) { sleep(1) }
      end

      describe '#status' do

        it 'returns Working' do
          subject.run
          expect(subject.status).to eq("Working")
        end
      end
    end
  end

  describe '#dispatch' do
    context 'when there are 2 connector_queue to be processed' do

      before do
        2.times { factory_create(:connector_queue_for_evidence) }
        @scope = "default"
        subject.stub(:process)
      end

      it 'calls #process twice' do
        subject.should_receive(:process).twice
        subject.dispatch(@scope)
      end

      it 'destroy all the connector_queue documents' do
        subject.dispatch(@scope)
        expect(ConnectorQueue.all.count).to be_zero
      end

      context 'there is an error during process' do

        before do
          turn_off_tracer(print_errors: false)
          subject.stub(:process).and_raise("foo bar")
        end

        it 'does not raise any expection' do
          expect { subject.dispatch(@scope) }.not_to raise_error
        end

        it 'does not delete the connector_queue' do
          subject.dispatch(@scope)
          expect(ConnectorQueue.all.count).to eq(2)
        end

        it 'fills up #thread_with_errors' do
          subject.dispatch(@scope)
          expect(subject.thread_with_errors).to eq([@scope])
        end
      end
    end
  end

  describe '#process' do

    let!(:connector_queue) { factory_create(:connector_queue_for_evidence) }

    it 'calls #dump' do
      subject.should_receive(:dump)
      subject.process(connector_queue)
    end

    context 'the connector is missing' do

      before { Connector.destroy_all }

      it 'does not raise any error nor calls #dump' do
        subject.should_not_receive(:dump)
        expect { subject.process(connector_queue) }.not_to raise_error
      end
    end

    context 'the evidence is missing' do

      before { ::Evidence.target(connector_queue.data[:target_id]).destroy_all }

      it 'does not raise any error nor calls #dump' do
        subject.should_not_receive(:dump)
        expect { subject.process(connector_queue) }.not_to raise_error
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
          connector.update_attributes format: 'XML'
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
