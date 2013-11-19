require 'spec_helper'
require_db 'db_layer'
require_db 'grid'

describe HandleBook do

  silence_alerts
  enable_license

  describe '#remove_target' do

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
      # Communications of alice
      expect(described_class.targets(:skype, 'bob')).to eq([target.id])
      expect(described_class.targets(:skype, 'steve')).to eq([target.id, target2.id])

      # Communications of bob
      expect(described_class.targets(:skype, 'mark')).to eq([target2.id])
    end

    it 'removes the target id from where it appears' do
      described_class.remove_target(target)

      # Communications of alice
      expect(described_class.targets(:skype, 'bob')).to be_blank
      expect(described_class.targets(:skype, 'steve')).to eq([target2.id])

      # Communications of bob
      expect(described_class.targets(:skype, 'mark')).to eq([target2.id])
    end

  end
end
