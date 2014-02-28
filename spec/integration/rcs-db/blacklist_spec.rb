# encoding: utf-8
require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe 'The scout has to be upgaded' do

  silence_alerts

  before do
    Item.any_instance.stub(:blacklist_path).and_return(fixtures_path('blacklist'))
  end

  let!(:operation) { factory_create(:operation) }
  let!(:target) { factory_create(:target, operation: operation) }
  let!(:agent) { factory_create(:agent, target: target) }

  before do
    agent.version = 3
    agent.level = :scout
  end

  context "blacklisted software is present" do

    let!(:evidence) { factory_create(:device_evidence, agent: agent)}

    it 'should detect unicode software and suggest soldier' do
      evidence.data = {content: "Architecture: 64-bit\n\nApplication list:\n 360杀毒"}
      evidence.save

      expect(agent.blacklisted_software?).to eq(:soldier)
    end

    it 'should detect ascii software' do
      evidence.data = {content: "Architecture: 64-bit\n\nApplication list:\n Outpost Antivirus 1.34"}
      evidence.save

      expect { agent.blacklisted_software? }.to raise_error BlacklistError, /prevents the upgrade/i
    end

    it 'should detect 32 bit software and suggest soldier' do
      evidence.data = {content: "Architecture: 32-bit\n\nApplication list:\n Kaspersky Antivirus"}
      evidence.save

      expect(agent.blacklisted_software?).to eq(:soldier)
    end

    it 'should not detect 64 bit software (if only 32 is in blacklist)' do
      evidence.data = {content: "Architecture: 64-bit\n\nApplication list:\n Kaspersky Antivirus"}
      evidence.save

      expect { agent.blacklisted_software? }.not_to raise_error
    end

    it 'should detect * bit software (on device info without bit infos)' do
      evidence.data = {content: "Application list:\n Online Armor"}
      evidence.save

      expect { agent.blacklisted_software? }.to raise_error BlacklistError, /prevents the upgrade/i
    end

  end

  context "blacklisted software is not installed" do

    let!(:evidence) { factory_create(:device_evidence, agent: agent)}

    it 'should not detect software that is not in blacklist' do
      evidence.data = {content: "Application list:\n McAfee Security Suite"}
      evidence.save

      expect { agent.blacklisted_software? }.not_to raise_error
    end

  end

  context "blacklisted software cannot be determined" do

    it 'should raise error if device info cannot be found' do
      expect { agent.blacklisted_software? }.to raise_error BlacklistError, /Cannot determine installed software/i
    end

  end

  context "analysis software is installed" do

    let!(:evidence) { factory_create(:device_evidence, agent: agent)}

    it 'should detect analysis software' do
      evidence.data = {content: "Application list:\n VMWare Tools"}
      evidence.save

      expect { agent.blacklisted_software? }.to raise_error BlacklistError, /malware analysis software/i
    end

  end
end
