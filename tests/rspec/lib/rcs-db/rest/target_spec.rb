require 'spec_helper'
require_db 'db_layer'
require_db 'rest'
require_db 'rest/target'

module RCS::DB
  describe TargetController do

    before do
      # skip check of current user privileges
      subject.stub :require_auth_level

      subject.stub(:mongoid_query).and_yield

      # stub the #ok method and then #not_found methods
      subject.stub(:ok) { |*args| args.first }
      subject.stub(:not_found) { |message| message }
    end

    describe '#positions' do

      let(:target1) { factory_create(:target) }

      let(:target2) { factory_create(:target) }

      before do
        t = Time.new(2000, 01, 01, 13, 42)

        factory_create(:position_evidence, target: target1, da: t.to_i, lat: 10, lon: 2)
        factory_create(:position_evidence, target: target2, da: (t + 5).to_i, lat: 12, lon: 2)
        factory_create(:position_evidence, target: target2, da: (t + 10).to_i, lat: 13, lon: 4)
        factory_create(:position_evidence, target: target1, da: (t + 60).to_i, lat: 11, lon: 2)
      end

      it 'returns the expected result' do
        target_ids = [target1.id, target2.id]
        subject.instance_variable_set('@params', {'ids' => target_ids})
        result = subject.positions

        expect(result.keys.count).to eq(2)
        expect(result[946730520]).to eq({target1.id => {:lat=>10, :lon=>2, :rad=>25}, target2.id => {:lat=>13, :lon=>4, :rad=>25}})
        expect(result[946730580]).to eq({target1.id => {:lat=>11, :lon=>2, :rad=>25}})
      end
    end
  end
end
