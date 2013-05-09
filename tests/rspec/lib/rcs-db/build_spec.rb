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
require_db 'build'

module RCS
module DB

  describe Build do

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

    context 'when builder\'s classes has been registered' do

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
  end

end
end
