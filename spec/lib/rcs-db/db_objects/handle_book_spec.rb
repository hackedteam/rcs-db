require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe HandleBook do

  silence_alerts
  enable_license

  let(:target) { factory_create(:target, name: 'alice') }

  let(:target2) { factory_create(:target, name: 'bob') }

  before do
    # Aggregates of alice
    factory_create(:aggregate, target: target, type: :skype, data: {peer: 'bob', versus: :out, sender: 'alice'} )
    factory_create(:aggregate, target: target, type: :skype, data: {peer: 'steve', versus: :out, sender: 'alice'} )

    # Aggregates of bob
    factory_create(:aggregate, target: target2, type: :skype, data: {peer: 'mark', versus: :out, sender: 'bob'} )
    factory_create(:aggregate, target: target2, type: :skype, data: {peer: 'steve', versus: :out, sender: 'bob'} )
  end

  before do
    expect(HandleBook.all.count).to eq(3)

    # Communications of alice
    expect(described_class.targets_that_communicate_with(:skype, 'bob')).to eq([target])
    expect(described_class.targets_that_communicate_with(:skype, 'steve')).to eq([target, target2])

    # Communications of bob
    expect(described_class.targets_that_communicate_with(:skype, 'mark')).to eq([target2])
  end

  describe '#remove_target' do
    it 'removes the target id from where it appears' do
      described_class.remove_target(target)

      expect(HandleBook.all.count).to eq(2)

      # Communications of alice
      expect(described_class.targets_that_communicate_with(:skype, 'bob')).to be_blank
      expect(described_class.targets_that_communicate_with(:skype, 'steve')).to eq([target2])

      # Communications of bob
      expect(described_class.targets_that_communicate_with(:skype, 'mark')).to eq([target2])
    end

  end

  describe '#rebuild' do
    it 'destroys and recreates all the records (based on aggregates)' do
      described_class.rebuild

      expect(HandleBook.all.count).to eq(3)

      # Communications of alice
      expect(described_class.targets_that_communicate_with(:skype, 'bob')).to eq([target])
      expect(described_class.targets_that_communicate_with(:skype, 'steve')).to eq([target, target2])

      # Communications of bob
      expect(described_class.targets_that_communicate_with(:skype, 'mark')).to eq([target2])
    end
  end
end
