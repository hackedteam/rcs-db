# encoding: utf-8
require 'spec_helper'
require 'fileutils'
require_db 'db_layer'
require_db 'grid'
require_db 'license'
require_db 'alert'

module RCS
  module Stubs
    class ArchiveNode
      def initialize(params = {})
        @address = params[:address] || 'localhost:4449'
        @db_name = params[:db_name] || 'rcs_archive_node'
        @path = File.expand_path(Dir.pwd)
        @config_file = "#{@path}/config/config.yaml"
        @license_file = "#{@path}/config/rcs.lic"
      end

      def run
        return if @thread

        backup(@config_file)
        backup(@license_file)

        # Change the database name and the server port
        File.open(@config_file, 'ab') do |f|
          f.puts "\n"
          f.puts "DB_NAME: #{@db_name}"
          f.puts "LISTENING_PORT: #{@address.split(':').last}"
        end

        # Change the license file, enabling archive mode
        lic_str = File.read(@license_file)
        File.open(@license_file, 'wb') do |f|
          f.write lic_str.gsub('archive: false', 'archive: true')
        end

        # Regenerate license checksums
        system('ruby ./scripts/rcs-db-license-gen.rb -i config/rcs.lic -o config/rcs.lic')

        # Clear the database
        db.drop

        # Launch the application
        @thread = Thread.new { system('./bin/rcs-db TESTARCHIVENODE=1') }

        sleep(14)
      ensure
        restore(@config_file)
        restore(@license_file)
      end

      def kill
        puts "Killing archive node on thread"
        str = `ps aux | grep TESTARCHIVENODE`
        pid = str.split("\n").find { |line| line =~ /ruby/ }.split(" ")[1] rescue nil
        system("kill -9 #{pid}")
      end

      def db
        @db ||= begin
          session = Moped::Session.new([ "127.0.0.1:27017"])
          session.use(@db_name)
          session.with(safe: true)
        end
      end

      def bak(filepath)
        "#{filepath}.bak"
      end

      def backup(filepath)
        FileUtils.cp(filepath, bak(filepath))
      end

      def restore(filename)
        FileUtils.mv(bak(filename), filename) if File.exists?(bak(filename))
      end
    end

  end
end

describe 'Sync with an archive node', speed: 'slow' do

  def archive
    $archive_node ||= RCS::Stubs::ArchiveNode.new
  end

  def connector_service
    $connector_service ||= RCS::Stubs::Connector.new
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
