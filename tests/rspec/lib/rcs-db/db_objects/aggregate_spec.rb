require 'spec_helper'
require_db 'db_layer'
require_db 'position/point'

describe Aggregate do
  use_db

  let (:aggregate_class) { Aggregate.target('testtarget') }

  describe '#target' do

    let(:first_aggregate) { Aggregate.target 'first_aggregate' }

    let(:second_aggregate) { Aggregate.target 'second_aggregate' }

    context 'when two or more classes are generated' do

      before { first_aggregate; second_aggregate }

      it 'refers to different collections' do
        expect(first_aggregate.collection.name).not_to eql second_aggregate.collection.name
      end
    end

    it 'accepts a mongoid document instance (not only a string)' do
      target = mock(id: 'an_id')
      expect(Aggregate.target(target).collection.name).to eql 'aggregate.an_id'
    end
  end

  describe '#collection_name' do

    it 'raises an error if @target_id is missing' do
      expect { Aggregate.collection_name }.to raise_error
    end
  end

  it 'raises an error when used without #target' do
    valid_attributes = {day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 1, data: {peer: 'test1', versus: :in}}

    expect { Aggregate.new }.to raise_error
    expect { Aggregate.create!(valid_attributes) }.to raise_error
  end

  describe '#to_point' do
    let!(:agg) {Aggregate.target('testtarget').create!(type: :position, data: {'position' => [9.1, 45.2], 'radius' => 50}, day: '20130405') }

    it 'should not convert if the aggregate is not a position' do
      agg.type = 'peer'
      expect { agg.to_point }.to raise_error RuntimeError, /not a position/i
    end

    it 'should convert the aggregate to a Point' do
      p = agg.to_point
      p.should be_a Point
      p.lat.should eq 45.2
      p.lon.should eq 9.1
      p.r.should eq 50
    end
  end

  describe '#positions_within' do
    before do
      Aggregate.target('testtarget').create_collection
    end

    it 'should return the points near the given position' do
      Aggregate.target('testtarget').create!(type: :position, data: {'position' => [9.5939346, 45.5353563], 'radius' => 50}, day: Time.now.strftime('%Y%m%d'), aid: 'test')
      Aggregate.target('testtarget').create!(type: :position, data: {'position' => [9.6039346, 45.5453563], 'radius' => 50}, day: Time.now.strftime('%Y%m%d'), aid: 'test')

      count_100 = Aggregate.target('testtarget').positions_within({longitude: 9.5945033, latitude: 45.5351362}, 100).count
      count_100.should eq 1

      count_1500 = Aggregate.target('testtarget').positions_within({longitude: 9.5945033, latitude: 45.5351362}, 1500).count
      count_1500.should eq 2
    end
  end

  it 'should create and retrieve summary' do
    aggregate_class.add_to_summary('test', 'peer')

    aggregates = aggregate_class.where(type: :summary)
    aggregates.size.should be 1
    entry = aggregates.first
    entry.info.should include 'test_peer'

    aggregate_class.summary_include?('test', 'peer').should be true
  end

  it 'should not duplicate summary' do
    aggregate_class.add_to_summary('test', 'peer')
    aggregate_class.add_to_summary('test', 'peer')
    aggregates = aggregate_class.where(type: :summary)
    aggregates.size.should be 1
  end

  it 'should not rebuild summary if empty' do
    aggregate_class.rebuild_summary

    aggregates = aggregate_class.where(type: :summary)
    aggregates.size.should be 0
  end

  context 'given some data' do
    before do
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 1, data: {peer: 'test1', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 2, data: {peer: 'test2', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :sms, aid: 'agent_id', count: 3, data: {peer: 'test3', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :skype, aid: 'agent_id', count: 1, data: {peer: 'test.ardo', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :skype, aid: 'agent_id', count: 2, data: {peer: 'test.one', versus: :in})
      aggregate_class.create!(day: Time.now.strftime('%Y%m%d'), type: :call, aid: 'agent_id', count: 3, data: {peer: 'test.ardissimo', versus: :in})
    end

    it 'does not rebuild summary when the mongo version is < 2.4' do
      RCS::DB::Config.instance.stub!(:mongo_version).and_return("2.2.4")
      aggregate_class.rebuild_summary
      expect(aggregate_class.where(type: :summary).all).to be_empty
    end

    it 'should be able to rebuild summary' do
      aggregate_class.rebuild_summary

      aggregates = aggregate_class.where(type: :summary)
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

      most_contacted.should include([{peer: "test.ardissimo", type: :call, count: 3, size: 0, percent: 100.0}])
      most_contacted.should include([{peer: "test3", type: :sms, count: 3, size: 0, percent: 50.0}])
      most_contacted.should include([{peer: "test.one", type: :skype, count: 2, size: 0, percent: 66.0}])
    end

    it 'should report the most (5) contacted' do
      params = {'from' => Time.now.strftime('%Y%m%d'), 'to' => Time.now.strftime('%Y%m%d'), 'num' => 5}
      most_contacted = Aggregate.most_contacted('testtarget', params)

      most_contacted.size.should be 3

      call = most_contacted[0]
      skype = most_contacted[1]
      sms = most_contacted[2]

      call.size.should be 1
      call.should include({peer: "test.ardissimo", type: :call, count: 3, size: 0, percent: 100.0})

      sms.size.should be 3
      sms.should include({:peer=>"test3", :type=>:sms, :count=>3, :size=>0, :percent=>50.0})
      sms.should include({:peer=>"test2", :type=>:sms, :count=>2, :size=>0, :percent=>33.0})
      sms.should include({:peer=>"test1", :type=>:sms, :count=>1, :size=>0, :percent=>16.0})

      skype.size.should be 2
      skype.should include({:peer=>"test.one", :type=>:skype, :count=>2, :size=>0, :percent=>66.0})
      skype.should include({:peer=>"test.ardo", :type=>:skype, :count=>1, :size=>0, :percent=>33.0})
    end
  end

  # Validations
  context 'when the "day" attribute is not in valid format' do

    let(:invalid_days) { [Time.now, Time.now.to_i, Time.now.to_f, Date.today, '2013/02/03', '2013-02-03'] }

    it 'is not valid' do
      invalid_days.each do |day|
        aggregate = described_class.target('target_id').new day: day
        aggregate.valid?
        expect(aggregate.errors).to include :day
      end
    end
  end

  # Validations
  context 'when the "day" attribute valid' do

    let(:valid_days) { ['0', '20130402', '99999999', 20130201] }

    it 'is valid' do
      valid_days.each do |day|
        aggregate = described_class.target('target_id').new day: day
        expect(aggregate).to be_valid
      end
    end
  end

  describe '#most_visited' do

    def url_aggregate day, host, count
      Aggregate.target('testtarget').create!(type: :url, day: day, aid: 'test', data: {host: host}, count: count)
    end

    before do
      url_aggregate '20130101', 'it.wikipedia.org', 30
      url_aggregate '20130103', 'google.com',       5
      url_aggregate '20130110', 'it.wikipedia.org', 20
      url_aggregate '20130113', '4chan.org',        10
      url_aggregate '20130113', 'google.com',       1
      url_aggregate '20130113', 'yahoo.com',        1
      url_aggregate '20130113', 'youtube.com',      1
      url_aggregate '20130114', 'reddit.com',       1
    end

    context 'called with no params' do

      before { @result = Aggregate.most_visited('testtarget', {}) }

      it 'returns the most visited' do
        expect(@result.size).to eql 5
        expect(@result[0]).to eql({"host" => 'it.wikipedia.org', "count" => 50, "percent" => 73.5})
        expect(@result[1]).to eql({"host" => '4chan.org',        "count" => 10, "percent" => 14.7})
        expect(@result[2]).to eql({"host" => 'google.com',       "count" => 6,  "percent" => 8.8})
      end
    end

    context 'called with "num"' do

      before { @result = Aggregate.most_visited('testtarget', {'num' => 2}) }

      it 'returns the most visited' do
        expect(@result.size).to eql 2
        expect(@result[0]).to eql({"host" => 'it.wikipedia.org', "count" => 50, "percent" => 83.3})
        expect(@result[1]).to eql({"host" => '4chan.org',        "count" => 10, "percent" => 16.7})
      end
    end

    context 'called with "from" and "to"' do

      before { @result = Aggregate.most_visited('testtarget', {'from' => '20130109', 'to' => '20130111'}) }

      it 'returns the most visited' do
        expect(@result.size).to eql 1
        expect(@result[0]).to eql({"host" => 'it.wikipedia.org', "count" => 20, "percent" => 100.0})
      end
    end
  end
end
