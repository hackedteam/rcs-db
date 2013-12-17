require 'spec_helper'
require 'fileutils'

require_db 'db_layer'
require_db 'grid'
require_db 'build'
require_db 'core'

module RCS::DB
  describe BuildLinux do
    enable_license

    let(:local_cores_path) { File.expand_path('../../../../../cores', __FILE__) }

    let(:remote_cores_path) { "/Volumes/SHARE/RELEASE/SVILUPPO/cores galileo" }

    let(:melt_file) { 'curl_7.32.0-1ubuntu1_i386.deb' }

    before(:all) do
      do_not_empty_test_db

      FileUtils.cp(fixtures_path(melt_file), Config.instance.temp)
      FileUtils.cp("#{remote_cores_path}/linux.zip", "#{local_cores_path}/")

      @signature = ::Signature.create!(scope: 'agent', value: 'A'*32)

      @factory = Item.create!(name: 'testfactory', _kind: :factory, path: [], stat: ::Stat.new, good: true).tap do |f|
        f.update_attributes logkey: 'L'*32, confkey: 'C'*32, ident: 'RCS_000000test', seed: '88888888.333'
        f.configs << Configuration.new({config: 'test_config'})
      end
    end

    def core_loaded?
      Mongoid.default_session['cores'].find(name: 'linux').first
    end

    before do
      subject.stub(:archive_mode?).and_return false
      RCS::DB::Build.any_instance.stub(:license_magic).and_return 'WmarkerW'

      unless core_loaded?
        RCS::DB::Core.load_core ('./cores/linux.zip')
      end
    end

    describe 'linux builder' do
      it 'should create the silent installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {}
        }

        subject.create(params)

        # # build successful
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
    end
  end
end
