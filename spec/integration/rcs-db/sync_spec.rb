# encoding: utf-8
require 'spec_helper'
require 'fileutils'
require_db 'db_layer'
require_db 'grid'
require_db 'license'
require_db 'alert'

describe 'Sync with an archive node', speed: 'slow' do

  def archive
    $archive_node ||= RCS::Stubs::ArchiveServer.new
  end

  def wait_for_network_action
    sleep(1)
  end

  silence_alerts

  before(:all) { archive.run }

  after(:all) { archive.kill }

  before { turn_on_tracer }

  let!(:operation) { factory_create(:operation) }

  let!(:target) { factory_create(:target, operation: operation) }

  let!(:network_signature) { factory_create(:signature, scope: 'network', value: 't0p4c') }

  before do
    3.times { factory_create(:signature) }
  end

  context 'after archive node startup' do

    describe 'the archive node' do

      it 'has a valid license' do
        license = archive.db[:license].find.first
        expect(license['archive']).to be_true
      end

      it 'does not have signatures' do
        expect(archive.db[:signatures].find.count).to eq(0)
      end
    end
  end

  describe 'the archive node' do

    let(:connector) { factory_create(:remote_connector, operation: operation) }

    let(:archive_node) { connector.archive_node }

    context 'when a connector is created' do

      before do
        connector
        wait_for_network_action
      end

      it 'obtains signatures' do
        expect(archive.db[:signatures].find.count).to eq(4)
      end

      context 'and than updated' do

        before { connector.update_attributes(name: "connector_#{rand(1E5)}") }

        it 'does not change signatures count' do
          expect(archive.db[:signatures].find.count).to eq(4)
        end
      end
    end

    context 'when a ping request is sended' do

      before do
        expect(archive_node.status).to be_nil
        archive_node.ping!
        wait_for_network_action
      end

      it 'updates the status of the archive node' do
        expect(archive_node.status).not_to be_nil
      end
    end

    context 'when a matching evidence is received' do

      # let!(:evidence) { factory_create(:position_evidence, target: target) }

      # before { evidence.enqueue }
    end
  end
end
