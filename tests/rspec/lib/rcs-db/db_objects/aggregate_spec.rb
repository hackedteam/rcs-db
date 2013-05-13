require 'spec_helper'
require_db 'db_layer'

describe Aggregate do
  use_db

  let (:aggregate_class) { Aggregate.collection_class('testtarget') }
  let (:aggregate_name) { Aggregate.collection_name('testtarget') }

  it 'should create and retrieve summary' do
    aggregate_class.add_to_summary('test', 'peer')

    aggregates = aggregate_class.where(type: 'summary')
    aggregates.size.should be 1
    entry = aggregates.first
    entry.info.should include 'test_peer'

    aggregate_class.summary_include?('test', 'peer').should be true
  end

  it 'should not duplicate summary' do
    aggregate_class.add_to_summary('test', 'peer')
    aggregate_class.add_to_summary('test', 'peer')
    aggregates = aggregate_class.where(type: 'summary')
    aggregates.size.should be 1
  end

  it 'should not rebuild summary if empty' do
    aggregate_class.rebuild_summary

    aggregates = aggregate_class.where(type: 'summary')
    aggregates.size.should be 0
  end

  context 'given some data' do
    before do
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'sms', aid: 'agent_id', count: 1, data: {peer: 'test1', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'sms', aid: 'agent_id', count: 2, data: {peer: 'test2', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'sms', aid: 'agent_id', count: 3, data: {peer: 'test3', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'skype', aid: 'agent_id', count: 1, data: {peer: 'test.ardo', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'skype', aid: 'agent_id', count: 2, data: {peer: 'test.one', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: 'call', aid: 'agent_id', count: 3, data: {peer: 'test.ardissimo', versus: :in})
    end

    it 'should be able to rebuild summary' do
      aggregate_class.rebuild_summary

      aggregates = aggregate_class.where(type: 'summary')
      aggregates.size.should be 1
      entry = aggregates.first
      entry.info.should include 'sms_test1'
      entry.info.should include 'sms_test2'
      entry.info.should include 'sms_test3'
    end

    it 'should report the most (1) contacted' do
      params = {'from' => Time.now.strftime('%Y%m%d'), 'to' => Time.now.strftime('%Y%m%d'), 'num' => 1}
      most_contacted = Aggregate.most_contacted('testtarget', params)

      most_contacted.size.should be 3

      most_contacted.should include([{peer: "test.ardissimo", type: "call", count: 3, size: 0, percent: 100.0}])
      most_contacted.should include([{peer: "test3", type: "sms", count: 3, size: 0, percent: 50.0}])
      most_contacted.should include([{peer: "test.one", type: "skype", count: 2, size: 0, percent: 66.0}])
    end

    it 'should report the most (5) contacted' do
      params = {'from' => Time.now.strftime('%Y%m%d'), 'to' => Time.now.strftime('%Y%m%d'), 'num' => 5}
      most_contacted = Aggregate.most_contacted('testtarget', params)

      most_contacted.size.should be 3

      call = most_contacted[0]
      skype = most_contacted[1]
      sms = most_contacted[2]

      call.size.should be 1
      call.should include({peer: "test.ardissimo", type: "call", count: 3, size: 0, percent: 100.0})

      sms.size.should be 3
      sms.should include({:peer=>"test3", :type=>"sms", :count=>3, :size=>0, :percent=>50.0})
      sms.should include({:peer=>"test2", :type=>"sms", :count=>2, :size=>0, :percent=>33.0})
      sms.should include({:peer=>"test1", :type=>"sms", :count=>1, :size=>0, :percent=>16.0})

      skype.size.should be 2
      skype.should include({:peer=>"test.one", :type=>"skype", :count=>2, :size=>0, :percent=>66.0})
      skype.should include({:peer=>"test.ardo", :type=>"skype", :count=>1, :size=>0, :percent=>33.0})
    end

  end

end