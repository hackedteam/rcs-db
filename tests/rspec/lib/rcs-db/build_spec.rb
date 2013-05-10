require 'spec_helper'

# Define a fake builder class
# All the real builders (BuildWindows, BuildOSX, etc.) are required an registered
# as soon as "build.rb" is required
module RCS
  module DB
    class BuildFake; end
  end
end

require_db 'db_layer'
require_db 'grid'
require_db 'build'

module RCS
module DB

  describe Build do

    use_db
    silence_alerts
    enable_license

    let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

    let!(:factory) { Item.create!(name: 'testfactory', _kind: :factory, path: [operation.id], stat: ::Stat.new, good: true) }

    let!(:core_content) { File.read fixtures_path('linux_core.zip') }

    let!(:core) { ::Core.create!(name: 'linux', _grid: GridFS.put(core_content), version: 42) }

    describe '#initialize' do

      it 'creates a temporary directory' do
        expect(Dir.exist? described_class.new.tmpdir).to be_true
      end

      context 'when called in same instant' do

        before { Time.stub(:now).and_return 42 }

        it 'does not create the same temp directory' do
          expect(described_class.new.tmpdir != described_class.new.tmpdir).to be_true
        end
      end
    end

    context "when builders' classes has been registered" do

      describe '#factory' do

        it 'returns an instance of that factory' do
          expect(described_class.factory(:osx)).to respond_to :patch
        end
      end
    end

    context 'when a class has "Build" in its name' do

      it 'is registered as a factory' do
        expect(described_class.factory(:fake)).to be_kind_of BuildFake
      end
    end

    describe '#load' do

      context 'when the core is not found' do

        # TODO remove the instance variable @platform in favour of an attr_accessor (for example)
        before { subject.instance_variable_set '@platform', :amiga }

        it 'raises an error' do
          expect { subject.load(nil) }.to raise_error RuntimeError, /core for amiga not found/i
        end
      end

      before { subject.instance_variable_set '@platform', :linux }

      context 'when the factory is not good' do

        before { factory.update_attributes good: false }

        it 'raises an error' do
          expect { subject.load('_id' => factory.id) }.to raise_error RuntimeError, /factory too old/i
        end
      end

      it 'saves to core content to the temporary folder' do
        subject.load nil
        expect(File.read subject.core_filepath).to binary_equals core_content
      end

      it 'finds the given factory' do
        expect { subject.load('_id' => factory.id) }.to change(subject, :factory).from(nil).to(factory)
      end
    end

    let :subject_loaded do
      subject.instance_variable_set '@platform', :linux
      subject.load('_id' => factory.id)
      subject
    end

    describe '#unpack' do

      it 'extracts the zip archive and delete it' do
        subject_loaded.unpack
        extracted_core_path = subject_loaded.path 'core'
        expect(File.exists? extracted_core_path).to be_true
        expect(File.exists? subject_loaded.core_filepath).to be_false
      end

      it 'fills the "outputs" array with the core filename' do
        expect { subject_loaded.unpack }.to change(subject_loaded, :outputs).from([]).to(['core'])
      end
    end

    let :subject_unpacked do
      subject_loaded.unpack
      subject_loaded
    end

    describe '#patch' do

      let!(:signature) { ::Signature.create! scope: 'agent', value: "#{'X'*31}S" }

      let(:factory_configuration) { Configuration.new config: 'h3llo' }

      let(:string_32_bytes_long) { 'w3st'*8 }

      before do
        factory.update_attributes logkey: "#{'X'*31}L", confkey: "#{'X'*31}C", ident: 'RCS_XXXXXXXXXA'
        factory.configs << factory_configuration

        subject_unpacked.stub(:license_magic).and_return 'XXXXXXXM'
        subject_unpacked.stub(:hash_and_salt).and_return string_32_bytes_long
      end

      it 'patches the core file' do
        subject_unpacked.patch core: 'core'
        patched_content = File.read subject_unpacked.path('core')

        expect(patched_content).to binary_include "evidence_key=#{string_32_bytes_long}"
        expect(patched_content).to binary_include "configuration_key=#{string_32_bytes_long}"
        expect(patched_content).to binary_include "pre_customer_key=#{string_32_bytes_long}"
        expect(patched_content).to binary_match /agent_id\=.{4}XXXXXXXXXA/
        expect(patched_content).to binary_match /wmarker=XXXXXXXM.{24}/
      end

      context 'when the "config" param is present' do

        let(:encrypted_config_data) { "\xD9\xED\x94\\\xECG\x9C\x8C\x8B\x1D\x18\x135\xDD?\x96E\b\xC7\xD1\xDC\bUq\x1F\xC3\xAFg\xBCa\xC15" }

        it 'write an encrypted configuration file' do
          subject_unpacked.patch core: 'core', config: 'cfg1'
          configuration_file_content = File.read subject_unpacked.path 'cfg1'
          expect(configuration_file_content).to binary_equals encrypted_config_data
        end

        it 'fills the "outputs" array with the configuration filename' do
          expect { subject_unpacked.patch core: 'core', config: 'cfg1' }.to change(subject_unpacked, :outputs).from(['core']).to(['core', 'cfg1'])
        end
      end
    end
  end

end
end
