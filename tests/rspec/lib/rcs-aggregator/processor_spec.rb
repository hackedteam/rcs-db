require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'position/point'
require_aggregator 'processor'

module RCS
module Aggregator

describe Processor do

  use_db
  silence_alerts
  enable_license

  context 'processing evidence from the queue' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @agent = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
      data = {'from' => ' sender ', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'test message'}
      @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'chat', data: data)
      @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
    end

    it 'should create intelligence queue' do
      Processor.process @entry
      entry, count = IntelligenceQueue.get_queued
      entry['target_id'].should eq @target._id.to_s
      entry['type'].should eq :aggregate
      # count is the number of queued after the entry that we already
      count.should be 0
    end

    context 'if intelligence is disabled' do
      before do
        Processor.stub(:check_intelligence_license).and_return false
      end

      it 'should not create intelligence queue' do
        Processor.process @entry
        entry, count = IntelligenceQueue.get_queued
        entry.should be_nil
        count.should be_nil
      end
    end

    context 'given an evidence of type "peer"' do
      before do
        data = {'from' => ' sender ', 'rcpt' => 'receiver', 'incoming' => 0, 'program' => 'skype', 'content' => 'test message'}
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'chat', data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: 'skype')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq 'skype'
        entry.size.should eq @evidence.data['content'].size
        entry.aid.should eq @agent._id.to_s
        entry.day.should eq Time.now.strftime('%Y%m%d')
        entry.data['peer'].should eq 'receiver'
        entry.data['sender'].should eq 'sender'
      end

      it 'should aggregate multiple evidence' do
        iteration = 5

        # process the same entry N times
        iteration.times do
          Processor.process @entry
        end

        aggregates = Aggregate.target(@target._id).where(type: 'skype')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be iteration
      end

      it 'should create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: 'summary')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.info.should include 'skype_receiver'
      end
    end

    context 'given an evidence of type "position"' do

      def new_position(data)
        evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'position', data: data)
        {'target_id' => @target._id, 'evidence_id' => evidence._id}
      end

      before do
        data = {'latitude' => 45.5353563, 'longitude' => 9.5939346, 'accuracy' => 50}
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'position', data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
      end

      it 'should not create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: 'summary')
        aggregates.size.should be 0
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: 'position')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq 'position'
        entry.aid.should eq @agent._id.to_s
        entry.day.should eq Time.now.strftime('%Y%m%d')
        entry.data['position'].should_not be_nil
      end

      it 'should aggregate multiple evidence' do
         iteration = 5

         # process the same entry N times
         iteration.times do
           Processor.process @entry
         end

         aggregates = Aggregate.target(@target._id).where(type: 'position')
         aggregates.size.should be 1

         entry = aggregates.first
         entry.count.should be iteration
      end

      it 'should alert intelligence for every position aggregation' do
        iteration = 5

        # process the same entry N times
        iteration.times do
          Processor.process @entry
        end

        entry, count = IntelligenceQueue.get_queued
        # count is the number of queued after the entry that we already
        count.should be 4
      end

      it 'should aggregate multiple similar positions' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: 'position')
        aggregates.size.should be 1

        # overlapping
        Processor.process new_position({'latitude' => 45.5353563, 'longitude' => 9.5939346, 'accuracy' => 100})

        aggregates = Aggregate.target(@target._id).where(type: 'position')
        aggregates.size.should be 1

        # similar (intersecting)
        Processor.process new_position({'latitude' => 45.5351362, 'longitude' => 9.5945033, 'accuracy' => 40})
        Processor.process new_position({'latitude' => 45.5353538, 'longitude' => 9.5936141, 'accuracy' => 45})

        aggregates = Aggregate.target(@target._id).where(type: 'position')
        aggregates.size.should be 1
      end
    end

  end

  context 'given some evidence to be parsed' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @agent = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
      @evidence = Evidence.dynamic_new('testtarget')
    end

    context 'when is a wrong type evidence' do
      before do
        @evidence.type = 'wrong'
      end

      it 'should not parse it' do
        @evidence.data = {}
        parsed = Processor.extract_data(@evidence)
        parsed.should be_a Array
        parsed.size.should be 0
      end
    end

    it 'should parse every type of peer evidence' do
      all_types = {chat: {'from' => ' sender ', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'test message'},
                   call: {'from' => ' sender ', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'duration' => 30},
                   message: {'type' => :mail, 'from' => 'Test account <test@account.com>', 'rcpt' => 'receiver@mail.com', 'incoming' => 1, 'body' => 'test mail'}}

      all_types.each_pair do |key, value|
        @evidence.type = key.to_s
        @evidence.data = value

        parsed = Processor.extract_data(@evidence)
        parsed.should be_a Array
        parsed.size.should be 1
      end
    end

    def new_position(time, data)
      Evidence.collection_class(@target._id).create!(da: time, aid: @agent._id, type: 'position', data: data)
    end

    it 'should parse position evidence' do
      # the STAY point is:
      # 45.514992 9.5873462 10 (2013-01-15 07:37:43 - 2013-01-15 07:40:43)
      data =
      "2013-01-15 07:36:43 45.5149089 9.5880504 25
      2013-01-15 07:36:43 45.515057 9.586814 3500
      2013-01-15 07:37:43 45.5149920 9.5873462 10
      2013-01-15 07:37:43 45.515057 9.586814 3500
      2013-01-15 07:38:43 45.5149920 9.5873462 15
      2013-01-15 07:38:43 45.515057 9.586814 3500
      2013-01-15 07:39:43 45.5148914 9.5873097 10
      2013-01-15 07:39:43 45.515057 9.586814 3500
      2013-01-15 07:40:43 45.5148914 9.5873097 10
      2013-01-15 07:40:43 45.515057 9.586814 3500
      2013-01-15 07:41:43 45.5147590 9.5821532 25"

      results = []

      data.each_line do |e|
        values = e.split(' ')
        time = Time.parse("#{values.shift} #{values.shift} +0100")
        lat = values.shift.to_f
        lon = values.shift.to_f
        r = values.shift.to_i

        results << Processor.extract_data(new_position(time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))
      end

      pending "implement this"

      results[0].should eq []
      results[1].should eq []
      results[2].should eq []
      results[3].should eq []
      results[4].should eq []
      results[5].should eq []
      results[6].should eq []
      results[7].should eq []
      # this should emit the stay point
      results[8][:point].should eq({:latitude=>45.514992, :longitude=>9.5873462, :radius=>10})
      results[9].should eq []
      results[10].should eq []
    end

  end
end

end
end
