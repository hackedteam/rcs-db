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

      let(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

      let(:factory) { Item.create!(name: 'testfactory', _kind: :target, path: [operation.id], stat: ::Stat.new) }

      let(:core_content) { 'c0r3_c0nt3nt' }

      let(:core_grid_id) { GridFS.put 'c0r3_c0nt3nt' }

      let!(:core) { ::Core.create(name: 'linux', _grid: core_grid_id, version: 42) }

      context 'when the core is not found' do

        # TODO remove the instance variable @platform in favour of an attr_accessor (for example)
        before { subject.instance_variable_set '@platform', :amiga }

        it 'raises an error' do
          expect { subject.load(nil) }.to raise_error RuntimeError, /core for amiga not found/i
        end
      end

      before { subject.instance_variable_set '@platform', :linux }

      it 'saves to core content to the temporary folder' do
        subject.load nil
        expect(File.read subject.core_filepath).to be_eql core_content
      end
    end
  end

end
end
