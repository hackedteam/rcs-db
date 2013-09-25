require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'position'

module RCS
module Intelligence

  describe Position do

    silence_alerts

    let!(:operation) { Item.create!(name: 'testoperation', _kind: 'operation', path: [], stat: ::Stat.new) }
    let!(:target) { Item.create!(name: 'testtarget', _kind: 'target', path: [operation._id], stat: ::Stat.new) }
    let!(:entity) { Entity.any_in({path: [target.id]}).first }
    let!(:agent) { Item.create!(name: 'testagent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }
    let!(:evidence_class) { Evidence.target(target.id) }

    def create_position_evidence data
      evidence_class.create! da: Time.now.to_i, aid: agent.id, type: :position, data: data
    end

    it 'should use the Tracer module' do
      described_class.should respond_to :trace
      subject.should respond_to :trace
    end

    describe '#save_last_position' do

      context "when the evidence has no longitude" do
        let(:evidence) { create_position_evidence 'latitude' => 42.3 }

        it 'should do nothing' do
          entity.should_not_receive :save
          described_class.save_last_position entity, evidence
        end
      end

      context 'when the evidence has no latitude' do
        let(:evidence) { create_position_evidence 'longitude' => 42.3 }

        it 'should do nothing' do
          entity.should_not_receive :save
          described_class.save_last_position entity, evidence
        end
      end

      context 'the "last_position" attribute of the entity' do

        context 'when the evidence has a latitude and a longitude' do
          let(:evidence) { create_position_evidence 'longitude' => 42.3, 'latitude' => 9.2 }

          it 'should contain the evidence\'s da (date aquired) in the :time key' do
            described_class.save_last_position entity, evidence
            entity.last_position[:time].should == evidence.da
          end

          it 'should change' do
            expect{ described_class.save_last_position entity, evidence}.to change(entity, :last_position)
          end

          it 'should persist the changes' do
            described_class.save_last_position entity, evidence
            last_position_value = entity.last_position.dup
            entity.reload
            entity.last_position.should == last_position_value
          end

          it 'should contain the given latitude and longitude' do
            described_class.save_last_position entity, evidence
            entity.last_position[:longitude].should == 42.3
            entity.last_position[:latitude].should == 9.2
          end

          context 'and an accuracy' do
            before { evidence[:data]['accuracy'] = 45.99 }

            it 'should contain the accuracy (truncated)' do
              described_class.save_last_position entity, evidence
              entity.last_position[:accuracy].should == 45
            end
          end
        end
      end
    end

    describe '#recurring_positions' do
      before do
        @day = 20130120
        @aggregate = factory_create(:position_aggregate, target: target, day: @day, lat: 1, lon: 2)
      end

      context 'when there are at least 3 position in the prev week' do
        before do
          factory_create(:position_aggregate, target: target, day: @day - 1, lat: 1, lon: 2, rad: 20)
          factory_create(:position_aggregate, target: target, day: @day - 2, lat: 1, lon: 2, rad: 10)
          factory_create(:position_aggregate, target: target, day: @day - 3, lat: 1, lon: 2, rad: 40)
          factory_create(:position_aggregate, target: target, day: @day - 3, lat: 7, lon: 8, rad: 40)
        end

        it 'returns their ids' do
          results = described_class.recurring_positions(target, @aggregate)
          expect(results).to eq([{:position=>[2, 1], :radius=>10}])
        end
      end

      context 'when there aren\'t at least 3 position in the prev week' do
        before do
          factory_create(:position_aggregate, target: target, day: @day - 1, lat: 1, lon: 2, rad: 20)
          factory_create(:position_aggregate, target: target, day: @day - 2, lat: 1, lon: 2, rad: 10)
          factory_create(:position_aggregate, target: target, day: @day - 8, lat: 1, lon: 2, rad: 40)
        end

        it 'returns their ids' do
          results = described_class.recurring_positions(target, @aggregate)
          expect(results).to eq([])
        end
      end
    end

    describe '#suggest_recurring_positions' do
      before do
        @aggregate = factory_create(:position_aggregate, target: target, day: 20130120, lat: 1, lon: 2)

        described_class.should respond_to(:recurring_positions)
        described_class.stub(:recurring_positions).and_return([{:position=>[9.1919074, 45.4768394], :radius=>100}])


        Entity.create_indexes
      end

      context "when there aren't similar position entities" do
        before { expect(Entity.positions).to be_empty }

        it 'creates a position entity' do
          Entity.any_instance.should_receive(:fetch_address).once

          expect {
            described_class.suggest_recurring_positions(target, @aggregate)
          }.to change(Entity.positions, :count).from(0).to(1)

          new_entity = Entity.positions.first

          expect(new_entity.position).to eq([9.1919074, 45.4768394])
          expect(new_entity.level).to eq(:suggested)
          expect(new_entity.position_attr['accuracy']).to eq(100)
          expect(new_entity.path).to eq([operation.id])
        end
      end

      context "when there are similar position entities" do
        before { factory_create(:position_entity, path: [operation.id], lat: 45.4768393, lon: 9.191905, rad: 150) }

        it 'does not create a new position entity' do
          expect {
            described_class.suggest_recurring_positions(target, @aggregate)
          }.not_to change(Entity.positions, :count)
        end
      end
    end
  end
end
end
