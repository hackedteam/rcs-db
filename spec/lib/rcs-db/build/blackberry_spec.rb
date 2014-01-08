require_relative 'shared'

module RCS::DB
  describe BuildBlackberry, build: true do

    shared_spec_for(:blackberry)

    before(:all) do
      RCS::DB::Config.instance.load_from_file
    end

    describe 'Blackberry builder' do
      it 'should create the silent installer (local)' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {},
          'package' => {'type' => 'local'}
        }

        subject.create(params)

        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the silent installer (remote)' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {},
          'package' => {'type' => 'remote'}
        }

        subject.create(params)

        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end
    end
  end
end
