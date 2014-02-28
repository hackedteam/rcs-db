require_relative 'shared'

module RCS::DB
  describe BuildAndroid, build: true do

    shared_spec_for(:android, melt: 'builds/melt_android.apk')

    before(:all) do
      RCS::DB::Config.instance.load_from_file
    end

    describe 'Android builder' do
      it 'should create the silent installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {},
          'package' => {}
        }

        subject.create(params)

        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the melted installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {'input' => melt_file},
          'package' => {}
        }

        subject.create(params)

        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the ugrade build' do
        @agent.upgrade!
      end
    end
  end
end
