require 'spec_helper'

require_db 'db_layer'
require_db 'grid'
require_db 'build'
require_db 'core'

module RCS
module DB


  describe BuildLinux do

    enable_license
    stub_temp_folder

    let!(:factory) { Item.create!(name: 'testfactory', _kind: :factory, path: [], stat: ::Stat.new, good: true) }
    let!(:signature) { ::Signature.create! scope: 'agent', value: 'A'*32 }

    before do
      turn_off_tracer
      subject.stub(:archive_mode?).and_return false

      factory.update_attributes logkey: 'L'*32, confkey: 'C'*32, ident: 'RCS_000000test', seed: '88888888.333'
      factory.configs << Configuration.new({config: 'test_config'})

      RCS::DB::Build.any_instance.stub(:license_magic).and_return 'WmarkerW'

      # TODO: this will patch the core and insert it in the db,
      # then the file is deleted, so cannot be reused by other tests
      # change it to support multiple tests
      RCS::DB::Core.load_core ('./cores/linux.zip')
    end

    describe 'linux builder' do

      it 'should create the silent installer' do
        params = { 'factory' => {'_id' => factory.id},
                   'binary' => {'demo' => false},
                   'melt' => {}}
        subject.create params

        # build successful
        expect(File.size(subject.path(subject.outputs.first))).to_not eql 0
      end

    end

  end

end
end
