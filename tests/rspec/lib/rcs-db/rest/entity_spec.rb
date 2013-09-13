require 'spec_helper'
require_db 'db_layer'
require_db 'rest'
require_db 'rest/entity'

module RCS
module DB

  describe EntityController do


    let!(:operation) { Item.create!(name: 'testoperation', _kind: :operation, path: [], stat: ::Stat.new) }

    # target factory
    def create_target name
      Item.create! name: "#{name}", _kind: :target, path: [operation.id], stat: ::Stat.new
    end

    def create_or_find_entity name, type, handles
      if type == :target
        entity = Entity.where(name: name, type: :target).first
      else
        entity = Entity.create! name: name, type: type, level: :ghost, path: [operation.id]
      end

      handles.each do |handle|
        entity.handles.create! level: :automatic, type: 'phone', handle: handle
      end

      entity
    end

    # aggregate factory
    def create_aggregate target, day, count, data
      Aggregate.target(target).create! day: day, type: 'sms', aid: 'agent_id', count: count.to_i, data: data
    end

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

      let!(:entity1) { factory_create(:target_entity, target: target1) }

      let!(:entity2) { factory_create(:target_entity, target: target2) }

      let(:t) { Time.new(2000, 01, 01, 13, 42).to_i }

      before do
        factory_create(:position_evidence, target: target1, da: t - 100,  lat: 19, lon: 21)
        factory_create(:position_evidence, target: target1, da: t + 0,    lat: 10, lon: 2)
        factory_create(:position_evidence, target: target1, da: t + 60,   lat: 11, lon: 2)

        factory_create(:position_evidence, target: target2, da: t + 0,   lat: 13, lon: 4)
        factory_create(:position_evidence, target: target2, da: t + 50,  lat: 12, lon: 2)
        factory_create(:position_evidence, target: target2, da: t + 10.minutes,  lat: 19, lon: 7)
      end

      it 'returns the expected result' do
        # ids = [entity1.id, entity2.id]
        ids = [entity2.id]
        subject.instance_variable_set('@params', {'ids' => ids, 'from' => (t-2.minutes), 'to' => (t+13.minutes)})
        results = subject.positions

        pending
        # expect(results.size).to eq(50+20+20)
        # expect(results.size).to eq(2)
        # expect(results).to include({:time=>946730580, :positions => [{:_id=>entity1.id, :position=>{:lat=>11, :lon=>2, :rad=>25}}]})
        # expect(results).to include({:time=>946730520, :positions=> [
        #   {:_id=>entity1.id, :position=>{:lat=>10, :lon=>2, :rad=>25}},
        #   {:_id=>entity2.id, :position=>{:lat=>13, :lon=>4, :rad=>25}}
        # ]})
      end
    end

    describe '#flow' do

      def flow_with_params from, to, entities
        subject.instance_variable_set '@params', 'ids' => entities, 'from' => from, 'to' => to
        subject.flow
      end

      context 'when there are two entities (a "target" and a "person")' do

        before do
          alice_target = create_target 'alice'
          @alice = create_or_find_entity 'alice', :target, ['alice_number']
          @bob = create_or_find_entity 'bob', :person, ['bob_number']

          # 20130501
          create_aggregate alice_target, '20130501', 42, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}
          create_aggregate alice_target, '20130501', 4, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :in}

          # 20130510
          create_aggregate alice_target, '20130510', 7, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}
        end

        it 'works when the other entity is not passed' do
          results = flow_with_params '20130501', '20131201', [@alice.id]

          expect(results).to be_empty
        end

        it 'works when all the entities are passed' do
          results = flow_with_params '20130501', '20131201', [@alice.id, @bob.id]

          expect(results.size).to eq(2)
          expect(results[0]).to eq({:date => "20130501", :flows => [
            {:from => @alice.id, :rcpt => @bob.id, :count => 42},
            {:from => @bob.id, :rcpt => @alice.id, :count => 4}
          ]})
          expect(results[1]).to eq({:date => "20130510", :flows => [{:from => @alice.id, :rcpt => @bob.id, :count => 7}]})
        end

        it 'works when the timeframe is restricted' do
          results = flow_with_params '20130509', '20130510', [@alice.id, @bob.id]

          expect(results.size).to eq(1)
          expect(results[0]).to eq({:date => "20130510", :flows => [{:from => @alice.id, :rcpt => @bob.id, :count => 7}]})
        end
      end


      context 'when there are two entities of type "target"' do

        before do
          alice_target = create_target 'alice'
          @alice = create_or_find_entity 'alice', :target, ['alice_number']
          bob_target = create_target 'bob'
          @bob = create_or_find_entity 'bob', :target, ['bob_number']

          # 20130501
          create_aggregate alice_target, '20130501', 42, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}
          create_aggregate alice_target, '20130501', 4, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :in}
          create_aggregate bob_target, '20130501', 30, {'sender' => 'bob_number', 'peer' => 'alice_number', 'versus' => :out}
          create_aggregate bob_target, '20130501', 77, {'sender' => 'bob_number', 'peer' => 'alice_number', 'versus' => :out}
          create_aggregate bob_target, '20130501', 80, {'sender' => 'bob_number', 'peer' => 'alice_number', 'versus' => :in}

          # 20130510
          create_aggregate alice_target, '20130510', 99, {'sender' => 'alice_number', 'peer' => 'bob_number', 'versus' => :out}

          # 20130511
          create_aggregate alice_target, '20130511', 1, {'sender' => 'alice_number', 'versus' => :out}
          create_aggregate alice_target, '20130511', 1, {'sender' => 'alice_number', 'versus' => :in}
          create_aggregate alice_target, '20130511', 1, {'peer' => 'bob_number', 'versus' => :out}
          create_aggregate alice_target, '20130511', 1, {'peer' => 'bob_number', 'versus' => :in}
        end

        it 'works when the other entity is not passed' do
          results = flow_with_params '20130501', '20131201', [@alice.id]
          expect(results).to be_empty
          # expect(results['20130501']).to be_blank
          # expect(results['20130510']).to be_blank
        end

        it 'does a SUM of the counters grouping by entities couple' do
          results = flow_with_params '20130501', '20131201', [@alice.id, @bob.id]

          expect(results.size).to eq(2)
          expect(results[0]).to eq({:date => "20130501", :flows => [
            {:from => @alice.id, :rcpt => @bob.id, :count => 42+80},
            {:from => @bob.id, :rcpt => @alice.id, :count => 4+30+77}
          ]})
          expect(results[1]).to eq({:date => "20130510", :flows => [{:from => @alice.id, :rcpt => @bob.id, :count => 99}]})
        end

        it 'discards aggregates only the "sender" or only the "peer" handle' do
          results = flow_with_params '20130501', '20131201', [@alice.id, @bob.id]
          entry = results.find { |hash| hash[:date] == '20130511' }
          expect(entry).to be_nil
        end

        it 'works when the timeframe is restricted' do
          results = flow_with_params '20130509', '20130510', [@alice.id, @bob.id]
          entry = results.find { |hash| hash[:date] == '20130501' }
          expect(entry).to be_nil
          entry = results.find { |hash| hash[:date] == '20130510' }
          expect(entry).to eq({:date => "20130510", :flows => [{:from => @alice.id, :rcpt => @bob.id, :count => 99}]})
          # expect(results['20130510']).to eql [@alice.id, @bob.id]=>99
        end
      end


      context 'benchmark', speed: 'slow' do

        before do
          # alice_target = create_target 'alice'
          # bob_target = create_target 'bob'
          # eve_target = create_target 'eve'

          # date = Time.new 2010, 01, 01
          # end_date = date + 1.year

          # other_peers = ["bob_number", "alice_number"]
          # 60.times { |i| other_peers << "number_#{i}" }

          # while date < end_date do
          #   other_peers.each do |peer|
          #     create_aggregate alice_target, date, 42, {'sender' => 'alice_number', 'peer' => peer, 'versus' => :out}
          #     create_aggregate bob_target, date, 30, {'sender' => 'bob_number', 'peer' => peer, 'versus' => :out}
          #     create_aggregate eve_target, date, 123, {'sender' => 'eve_number', 'peer' => peer, 'versus' => :out}

          #     create_aggregate alice_target, date, 77, {'peer' => 'alice_number', 'sender' => peer, 'versus' => :in}
          #     create_aggregate bob_target, date, 88, {'peer' => 'bob_number', 'sender' => peer, 'versus' => :in}
          #     create_aggregate eve_target, date, 934, {'peer' => 'eve_number', 'sender' => peer, 'versus' => :in}
          #   end
          #   date += 1.day
          # end
          mongorestore "rcs-test_dump_for_entity_flow_benchmark.dump"

          @alice = create_or_find_entity 'alice', :target, ['alice_number']
          @bob = create_or_find_entity 'bob', :target, ['bob_number']
          @eve = create_or_find_entity 'eve', :target, ['eve_number']
        end

        it 'reports that #flow is fast' do
          start_time = Time.now
          results = flow_with_params '20000101', '20990101', [@alice.id, @bob.id, @eve.id]
          execution_time = Time.now - start_time
          expect(execution_time).to satisfy { |value| value < 5 }
        end
      end
    end
  end

end
end
