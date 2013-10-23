require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'position/point'
require_db 'position/positioner'
require_aggregator 'position'

module RCS
module Aggregator

describe PositionAggregator do
  silence_alerts

  describe '#find_similar_or_create_by'do
    let!(:target_id) {'testtarget'}
    let!(:aggregate) {Aggregate.target(target_id)}

    before do
      aggregate.create_collection
      @past = aggregate.create!(aid: 'test', day: Time.now.strftime('%Y%m%d'), type: :position,
                                data: {:position=>[9.5939346, 45.5353563], :radius=>50})
    end

    it 'should create a new aggregate if no points is similar' do
      params = {aid: 'test', day: Time.now.strftime('%Y%m%d'), type: :position,
                data: {position: {longitude: 9.60, latitude: 45.54, radius: 50}}}

      agg = described_class.find_similar_or_create_by(target_id, params)
      agg.id.should_not eq @past.id

      aggregate.count.should be 2
    end

    it 'should find similar points already aggregated today' do
      params = {aid: 'test', day: Time.now.strftime('%Y%m%d'), type: :position,
                data: {position: {longitude: 9.5939356, latitude: 45.5353573, radius: 50}}}

      agg = described_class.find_similar_or_create_by(target_id, params)
      agg.id.should eq @past.id

      aggregate.count.should be 1
    end

    context 'point found in the past with different dates' do
      it 'should create a new aggregate' do
        params = {aid: 'test', day: (Time.now + 86400).strftime('%Y%m%d'), type: :position,
                  data: {position: {longitude: 9.5939356, latitude: 45.5353573, radius: 50}}}

        agg = described_class.find_similar_or_create_by(target_id, params)
        agg.id.should_not eq @past.id

        aggregate.count.should be 2
      end

      it 'should create a new aggregate with old coordinates' do
        params = {aid: 'test', day: (Time.now + 86400).strftime('%Y%m%d'), type: :position,
                  data: {position: {longitude: 9.5939356, latitude: 45.5353573, radius: 50}}}

        agg = described_class.find_similar_or_create_by(target_id, params)
        agg.reload
        @past.reload
        agg.id.should_not eq @past.id
        agg.data['position'].should eq @past.data['position']
      end
    end
  end

  describe '#extract' do
    before do
      @target = Item.create!(name: 'test-target', _kind: 'target', path: [], stat: ::Stat.new)
      @agent1 = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)
      @agent2 = Item.create(name: 'test-agent', _kind: 'agent', path: [@target._id], stat: ::Stat.new)

      # the STAY point is:
      # 45.514992 9.5873462 10 (2013-01-15 07:37:43 - 2013-01-15 07:48:43)
      @data1 =
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

      # the STAY point is:
      # 45.514992 9.5873462 10 (2013-01-15 07:37:43 - 2013-01-15 07:54:43)
      @data2 =
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
      2013-01-15 07:51:43 45.5148913 9.5873097 50
      2013-01-15 07:52:43 45.5148914 9.5873098 50
      2013-01-15 07:53:43 45.5148915 9.5873099 50
      2013-01-15 07:54:43 45.5148914 9.5873097 50
      2013-01-15 07:55:43 45.5147590 9.5821532 25"
    end

    def new_position(device, time, data)
      Evidence.target(@target.id).new(da: time.to_i, aid: device.id, type: :position, data: data)
    end

    def parse_data(entry)
      values = entry.split(' ')
      time = Time.parse("#{values.shift} #{values.shift} +0100")
      lat = values.shift.to_f
      lon = values.shift.to_f
      r = values.shift.to_i
      return time, lat, lon, r
    end

    it 'should be able to reload previous status if stopped' do
      time, lat, lon, r = parse_data(@data1.each_line.first)
      described_class.extract(@target.id, new_position(@agent1, time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))

      aggregates = Aggregate.target(@target.id).where(type: :positioner)
      aggregates.size.should be 1
      aggregates.first.data[@agent1.id.to_s].should_not be nil
    end

    it 'should return only stay positions' do
      results = []

      @data1.each_line do |e|
        time, lat, lon, r = parse_data(e)
        point = described_class.extract(@target.id, new_position(@agent1, time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))
        results += point unless point.empty?
      end

      results.size.should be 1
      results.first[:point].should eq({latitude: 45.514992, longitude: 9.5873462, radius: 10})
    end

    it 'should keep track of multiple devices at the same time' do
      results = []

      @data1.each_line do |e|
        time, lat, lon, r = parse_data(e)
        point = described_class.extract(@target.id, new_position(@agent1, time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))
        results += point unless point.empty?
      end

      @data2.each_line do |e|
        time, lat, lon, r = parse_data(e)
        point = described_class.extract(@target.id, new_position(@agent2, time, {'latitude' => lat, 'longitude' => lon, 'accuracy' => r}))
        results += point unless point.empty?
      end

      results.size.should be 2
      first = results[0]
      second = results[1]

      first[:point].should eq({latitude: 45.514992, longitude: 9.5873462, radius: 10})
      first[:timeframe].should eq({start: Time.parse('2013-01-15 07:37:43'), end: Time.parse('2013-01-15 07:48:43')})

      second[:point].should eq({latitude: 45.514992, longitude: 9.5873462, radius: 10})
      second[:timeframe].should eq({start: Time.parse('2013-01-15 07:37:43'), end: Time.parse('2013-01-15 07:54:43')})
    end

  end
end


end
end
