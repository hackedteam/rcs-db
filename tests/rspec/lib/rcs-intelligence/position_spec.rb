require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_intelligence 'position'

module RCS
module Intelligence

  describe Position do

    use_db
    silence_alerts

    let!(:operation) { Item.create!(name: 'testoperation', _kind: 'operation', path: [], stat: ::Stat.new) }
    let!(:target) { Item.create!(name: 'testtarget', _kind: 'target', path: [operation._id], stat: ::Stat.new) }
    let!(:entity) { Entity.any_in({path: [target.id]}).first }
    let!(:agent) { Item.create!(name: 'testagent', _kind: 'agent', path: target.path+[target._id], stat: ::Stat.new) }
    let!(:evidence_class) { Evidence.collection_class(target.id) }

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
  end

end
end
