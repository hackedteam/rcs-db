require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
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
        data = {'from' => ' sender ', 'rcpt' => 'receiver', 'incoming' => 1, 'program' => 'skype', 'content' => 'test message'}
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'chat', data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.collection_class(@target._id).where(type: 'skype')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq 'skype'
        entry.size.should eq @evidence.data['content'].size
        entry.aid.should eq @agent._id.to_s
        entry.day.should eq Time.now.strftime('%Y%m%d')
      end

      it 'should aggregate multiple evidence' do
        iteration = 5

        # process the same entry N times
        iteration.times do
          Processor.process @entry
        end

        aggregates = Aggregate.collection_class(@target._id).where(type: 'skype')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be iteration
      end

      it 'should create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.collection_class(@target._id).where(type: 'summary')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.info.should include 'skype_sender'
      end
    end

    context 'given an evidence of type "position"' do
      before do
        data = {'latitude' => 45, 'longitude' => 9, 'accuracy' => 50}
        @evidence = Evidence.collection_class(@target._id).create!(da: Time.now.to_i, aid: @agent._id, type: 'position', data: data)
        @entry = {'target_id' => @target._id, 'evidence_id' => @evidence._id}
      end

      it 'should not create aggregation summary' do
        Processor.process @entry

        aggregates = Aggregate.collection_class(@target._id).where(type: 'summary')
        aggregates.size.should be 0
      end

      it 'should create aggregate from evidence' do
        Processor.process @entry

        aggregates = Aggregate.collection_class(@target._id).where(type: 'position')
        aggregates.size.should be 1

        entry = aggregates.first
        entry.count.should be 1
        entry.type.should eq 'position'
        entry.aid.should eq @agent._id.to_s
        entry.day.should eq Time.now.strftime('%Y%m%d')
        entry.data['point']['latitude'].should_not be_nil
        entry.data['point']['longitude'].should_not be_nil
        entry.data['point']['radius'].should_not be_nil
      end

      it 'should aggregate multiple evidence' do
         iteration = 5

         # process the same entry N times
         iteration.times do
           Processor.process @entry
         end

         aggregates = Aggregate.collection_class(@target._id).where(type: 'position')
         aggregates.size.should be 1

         entry = aggregates.first
         entry.count.should be iteration
      end
    end


  end

  context 'given some evidence to be parsed' do
    before do
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
  end
end

end
end
