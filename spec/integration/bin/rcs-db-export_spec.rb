require 'spec_helper'
require 'fileutils'

require_db 'db_layer'
require_db 'grid'

describe 'the rcs-db-export utility', slow: true do

  enable_license

  silence_alerts

  let(:username) { "jonh" }

  let(:pass) { "Password123" }

  let(:path) { File.join($execution_directory, 'bin/rcs-db-export') }

  let(:destination) { spec_temp_folder("rcs_db_export") }

  # Overwrite the ENV variable MONGOID_DATABASE
  def run(args = nil); `MONGOID_DATABASE=rcs-test; #{path} #{args}`; end

  let!(:user) { factory_create(:user, name: username, pass: pass) }

  let!(:target) { factory_create(:target, name: 'bar', user_ids: [user.id]) }

  before do
    FileUtils.rm_rf(destination)
  end

  context 'when the target is missing' do

    it 'returns an error' do
      expect(run("-d #{destination} -u #{username} -p #{pass} --target bob")).to match(/Unable to find target/)
    end
  end

  context 'when the user cannot access the target' do

    before { factory_create(:target, name: 'foo') }

    it 'returns an error' do
      expect(run("-d #{destination} -u #{username} -p #{pass} --target foo")).to match(/cannot access to the given target/)
    end
  end

  context 'when the target is founded' do

    before do
      expect(Dir[destination+"/*"]).to be_empty
      factory_create(:screenshot_evidence, target: target)
    end

    it 'export the evidence' do
      expect(run("-d #{destination} -u #{username} -p #{pass} --target bar")).not_to match(/error/i)

      expect(Dir[destination+"/style"]).not_to be_empty
      expect(Dir[destination+"/index.html"]).not_to be_empty
    end
  end

  context '--time-split filter' do

    before do
      factory_create(:chat_evidence, target: target, da: Time.new(2013,01,01))
      factory_create(:chat_evidence, target: target, da: Time.new(2013,02,01))
      factory_create(:chat_evidence, target: target, da: Time.new(2013,02,02))
    end

    context "1d" do

      it 'split the destination into a folder per day' do
        run("-d #{destination} -u #{username} -p #{pass} --target bar --time-split 1d")

        expect(Dir[destination+"/part_*"].size).to eq(3)
        expect(Dir[destination+"/part_1/2013-01-01"]).not_to be_empty
        expect(Dir[destination+"/part_2/2013-02-01"]).not_to be_empty
        expect(Dir[destination+"/part_3/2013-02-02"]).not_to be_empty
      end
    end

    context "1m" do

      it 'split the destination into a folder per month' do
        run("-d #{destination} -u #{username} -p #{pass} --target bar --time-split 1m")

        expect(Dir[destination+"/part_*"].size).to eq(2)
        expect(Dir[destination+"/part_1/2013-01-01"]).not_to be_empty
        expect(Dir[destination+"/part_2/2013-02-01"]).not_to be_empty
        expect(Dir[destination+"/part_2/2013-02-02"]).not_to be_empty
      end
    end

    context "2d" do

      it 'split the destination into a folder for every 2 days' do
        run("-d #{destination} -u #{username} -p #{pass} --target bar --time-split 2d")

        expect(Dir[destination+"/part_*"].size).to eq(2)
        expect(Dir[destination+"/part_1/2013-01-01"]).not_to be_empty
        expect(Dir[destination+"/part_2/2013-02-01"]).not_to be_empty
        expect(Dir[destination+"/part_2/2013-02-02"]).not_to be_empty
      end
    end

    context "60d" do

      it 'split the destination into a folder for every 2 days' do
        run("-d #{destination} -u #{username} -p #{pass} --target bar --time-split 60d")

        expect(Dir[destination+"/part_*"].size).to eq(1)
      end
    end
  end
end
