require 'spec_helper'
require_db 'db_layer'
require_db 'position/point'
require_aggregator 'position'

module RCS
module Aggregator

describe PositionAggregator do
  use_db

  describe '#find_similar_or_create_by'do
    let!(:target_id) {'testtarget'}
    let!(:aggregate) {Aggregate.target(target_id)}

    before do
      aggregate.create_collection
      @past = aggregate.create!(aid: 'test', day: Time.now.strftime('%Y%m%d'), type: 'position',
                                data: {:position=>[9.5939346, 45.5353563], :radius=>50})
    end

    it 'should create a new aggregate if no points is similar' do
      params = {aid: 'test', day: Time.now.strftime('%Y%m%d'), type: 'position',
                data: {:position=>[9.60, 45.54], :radius=>50}}

      agg = described_class.find_similar_or_create_by(target_id, params)
      agg.id.should_not eq @past.id

      aggregate.count.should be 2
    end

    it 'should find similar points already aggregated today' do
      params = {aid: 'test', day: Time.now.strftime('%Y%m%d'), type: 'position',
                data: {:position=>[9.5939356, 45.5353573], :radius=>50}}

      agg = described_class.find_similar_or_create_by(target_id, params)
      agg.id.should eq @past.id

      aggregate.count.should be 1
    end

    context 'point found in the past with different dates' do
      it 'should create a new aggregate' do
        params = {aid: 'test', day: (Time.now + 86400).strftime('%Y%m%d'), type: 'position',
                  data: {:position=>[9.5939356, 45.5353573], :radius=>50}}

        agg = described_class.find_similar_or_create_by(target_id, params)
        agg.id.should_not eq @past.id

        aggregate.count.should be 2
      end

      it 'should create a new aggregate with old coordinates' do
        params = {aid: 'test', day: (Time.now + 86400).strftime('%Y%m%d'), type: 'position',
                  data: {:position=>[9.5939356, 45.5353573], :radius=>50}}

        agg = described_class.find_similar_or_create_by(target_id, params)
        agg.reload
        @past.reload
        agg.id.should_not eq @past.id
        agg.data['position'].should eq @past.data['position']
      end
    end

  end

end


end
end
