require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'position/point'
require_db 'position/positioner'
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
      @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: :chat, data: data)
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
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: :chat, data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: :skype)
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq :skype
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

        aggregates = Aggregate.target(@target._id).where(type: :skype)
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be iteration
      end

      it 'should create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: :summary)
        aggregates.size.should be 1

        entry = aggregates.first
        entry.info.should include 'skype_receiver'
      end
    end

    context 'given an evidence of type "position"' do

      def new_position(data)
        evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: :position, data: data)
        {'target_id' => @target._id, 'evidence_id' => evidence._id}
      end

      before do
        data = {'latitude' => 45.5353563, 'longitude' => 9.5939346, 'accuracy' => 50}
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: :position, data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
        PositionAggregator.stub(:extract) do |target, ev|
          [{type: :position,
            time: ev.da,
            point: {latitude: ev.data['latitude'], longitude: ev.data['longitude'], radius: ev.data['accuracy']},
            timeframe: {start: ev.da, end: ev.da + 1000}}]
        end
      end

      it 'should not create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: :summary)
        aggregates.size.should be 0
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.target(@target._id).where(type: :position)
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq :position
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

         aggregates = Aggregate.target(@target._id).where(type: :position)
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
        parsed = Processor.extract_data(@target.id, @evidence)
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

        parsed = Processor.extract_data(@target.id, @evidence)
        parsed.should be_a Array
        parsed.size.should be 1
      end
    end

    def new_position(time, data)
      Evidence.collection_class(@target._id).create!(da: time, aid: @agent._id, type: :position, data: data)
    end

    it 'should parse position evidence' do
      # the STAY point is:
      # 45.514992 9.5873462 10 (2013-01-15 07:37:43 - 2013-01-15 07:48:43)
      data =
      "2013-01-15 07:36:43 45.5149089 9.5880504 25
      2013-01-15 07:36:43 45.515057 9.586814 3500
      2013-01-15 07:37:43 45.5149920 9.5873462 10
      2013-01-15 07:37:43 45.515057 9.586814 3500
      2013-01-15 07:38:43 45.5149920 9.5873462 15
      2013-01-15 07:38:43 45.515057 9.586814 3500
      2013-01-15 07:43:43 45.5148914 9.5873097 10
      2013-01-15 07:43:43 45.515057 9.586814 3500
      2013-01-15 07:48:43 45.5148914 9.5873097 10
      2013-01-15 07:48:43 45.515057 9.586814 3500
      2013-01-15 07:49:43 45.5147590 9.5821532 25"

      results = []

      data.each_line do |e|
        values = e.split(' ')
        time = Time.parse("#{values.shift} #{values.shift} +0100")
        lat = values.shift.to_f
        lon = values.shift.to_f
        r = values.shift.to_i

        results << Processor.extract_data(@target.id, new_position(time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))
      end

      results[0].should eq []
      results[1].should eq []
      results[2].should eq []
      results[3].should eq []
      results[4].should eq []
      results[5].should eq []
      results[6].should eq []
      results[7].should eq []
      results[8].should eq []
      results[9].should eq []
      # this should emit the stay point
      results[10].should_not eq []

      results[10].first[:point].should eq({:latitude=>45.514992, :longitude=>9.5873462, :radius=>10})
      results[10].first[:timeframe].should eq({start: Time.parse('2013-01-15 07:37:43'), end: Time.parse('2013-01-15 07:48:43')})
    end

  end

  context 'given a bounch of positions (multiple days)' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @agent = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
      @evidence = Evidence.dynamic_new('testtarget')
    end

    def parse_data(data)
      data.each_line do |e|
        values = e.split(' ')
        time = Time.parse("#{values.shift} #{values.shift} UTC")
        lat = values.shift.to_f
        lon = values.shift.to_f
        r = values.shift.to_i

        yield time, lat, lon, r if block_given?
      end
    end

    def new_position(time, data)
      Evidence.collection_class(@target._id).create!(da: time, aid: @agent._id, type: :position, data: data)
    end

    it 'should emit two consecutive points if reset at midnight' do
      # the STAY point is:
      # 45.123456 9.987654 10 (2012-12-31 23:45:00 - 2013-01-01 00:15:00)
      points =
      "2012-12-31 23:45:00 45.123456 9.987654 10
      2012-12-31 23:48:00 45.123456 9.987654 10
      2012-12-31 23:51:00 45.123456 9.987654 10
      2012-12-31 23:54:00 45.123456 9.987654 10
      2012-12-31 23:57:00 45.123456 9.987654 10
      2013-01-01 00:00:00 45.123456 9.987654 10
      2013-01-01 00:03:00 45.123456 9.987654 10
      2013-01-01 00:06:00 45.123456 9.987654 10
      2013-01-01 00:09:00 45.123456 9.987654 10
      2013-01-01 00:12:00 45.123456 9.987654 10
      2013-01-01 00:15:00 45.123456 9.987654 10
      2013-01-02 01:15:00 45.123456 9.987654 10" #fake one to trigger the data hole

      parse_data(points) do |time, lat, lon, r|
        ev = new_position(time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r})
        Processor.process('target_id' => @target.id, 'evidence_id' => ev)
      end

      results = Aggregate.target(@target.id).where(type: :position).order_by([[:day, :asc]])

      results.size.should be 2
      first = results.first
      second = results.last

      first.day.should eq '20121231'
      second.day.should eq '20130101'

      first.data['position'].should eq [9.987654, 45.123456]
      second.data['position'].should eq [9.987654, 45.123456]

      first.info.size.should be 1
      first.info.first['start'].should eq Time.parse('2012-12-31 23:45:00 UTC')
      first.info.first['end'].should eq Time.parse('2012-12-31 23:57:00 UTC')

      second.info.size.should be 1
      second.info.first['start'].should eq Time.parse('2013-01-01 00:00:00 UTC')
      second.info.first['end'].should eq Time.parse('2013-01-01 00:15:00 UTC')
    end

    it 'should output correctly data from t1', speed: 'slow' do
      points = File.read(File.join(fixtures_path, 'positions.t1.txt'))

      parse_data(points) do |time, lat, lon, r|
        ev = new_position(time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r})
        Processor.process('target_id' => @target.id, 'evidence_id' => ev)
      end

      results = Aggregate.target(@target.id).where(type: :position).order_by([[:day, :asc]]).to_a

      results.each do |p|
        puts "#{p[:day]}"
        puts "#{p[:data]['position'][1]} #{p[:data]['position'][0]} #{p[:data]['radius']}"
        puts p[:info]
        puts
      end

      #binding.pry

    end

  end

end

end
end
