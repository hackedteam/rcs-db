require 'spec_helper'
require 'fileutils'

require_db 'db_layer'
require_db 'grid'
require_db 'build'
require_db 'core'

require_relative 'shared'

# Note: signtool.exe should be executed with administrative privileges

module RCS::DB
  describe BuildWinMo do

    shared_spec_for(:winmo)

    before(:all) do
      RCS::DB::Config.instance.load_from_file

      @signature = ::Signature.create!(scope: 'agent', value: 'A'*32)

      @factory = Item.create!(name: 'testfactory', _kind: :factory, path: [], stat: ::Stat.new, good: true).tap do |f|
        f.update_attributes logkey: 'L'*32, confkey: 'C'*32, ident: 'RCS_000000test', seed: '88888888.333'
        f.configs << Configuration.new({config: 'test_config'})
      end
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
    end
  end
end
