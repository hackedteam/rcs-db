require_relative 'shared'

module RCS::DB
  describe BuildAnon, build: true do

    shared_spec_for(:anon)

    before(:all) do
      RCS::DB::Config.instance.load_from_file
    end

    describe 'Anon builder' do
      it 'should create the silent installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {},
          'package' => {}
        }

        subject.create(params)

        subject.outputs.each do |name|
          path = subject.path(name)
          size = File.size(path)
          expect(size).not_to eql(0)
        end
      end
    end
  end
end
