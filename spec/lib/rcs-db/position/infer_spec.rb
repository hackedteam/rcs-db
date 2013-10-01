require 'spec_helper'
require_db 'db_layer'
require_db 'grid'
require_db 'position/infer'

describe RCS::DB::Position::Infer do

  silence_alerts

  let(:day) { Date.new(2013, 7, 29) }

  let(:target) { factory_create(:target) }

  let(:subject) { described_class.new(target, day) }

  def info(*dates)
    dates.map { |couple| {'start' => Time.parse(couple[0]), 'end' => Time.parse(couple[1])} }
  end

  describe '#week_bounds' do
    it 'returns the first (monday) and the last day (sunday) of the week' do
      from, to = subject.week_bounds(day)

      expect(from).to eq("20130729")
      expect(to).to eq("20130804")
    end
  end

  before do
    factory_create(:position_aggregate, target: target, day: "20130729", lat: 1, lon: 2, rad: 50, info: info(['2013-07-29 13:49:28 UTC', '2013-07-29 17:45:36 UTC']), data: {'timezone' => +3})
    factory_create(:position_aggregate, target: target, day: "20130730", lat: 1, lon: 2, rad: 50, info: info(['2013-07-30 9:49:28 UTC', '2013-07-30 17:50:36 UTC']), data: {'timezone' => +3})
  end

  describe '#each_aggregate' do
    it 'yields for all the position aggregates' do
      position_aggregates = Aggregate.target(target).positions
      expect { |b| subject.each_aggregate(&b) }.to yield_successive_args(*position_aggregates)
    end
  end

  describe '#normalize_datetime' do
    it 'floors the datetime to the prev half hour' do
      expect(subject.normalize_datetime(Time.new(2013, 9, 1, 14, 42, 1))).to eq(Time.new(2013, 9, 1, 14, 30, 00))
      expect(subject.normalize_datetime(Time.new(2013, 9, 1, 14, 12, 9))).to eq(Time.new(2013, 9, 1, 14, 00, 00))
    end
  end

  describe '#office' do
    context 'when there are not enough days with positions aggregates' do
      it 'returns nil' do
        expect(subject.office).to be_nil
      end
    end

    context "when there are not enough positions" do
      before do
        factory_create(:position_aggregate, target: target, day: "20130731", lat: 1, lon: 2, rad: 50, info: info(['2013-07-31 9:49:28 UTC', '2013-07-31 11:45:36 UTC']), data: {'timezone' => +1})
        factory_create(:position_aggregate, target: target, day: "20130801", lat: 1, lon: 2, rad: 50, info: info(['2013-08-01 9:49:28 UTC', '2013-08-01 17:45:36 UTC']), data: {'timezone' => +1})
      end

      it 'returns nil' do
        expect(subject.office).to be_nil
      end
    end

    context "when there are enough positions" do
      before do
        factory_create(:position_aggregate, target: target, day: "20130802", lat: 1, lon: 2, rad: 50, info: info(['2013-08-02 7:49:28 UTC', '2013-08-02 19:45:36 UTC']), data: {'timezone' => +1})
        factory_create(:position_aggregate, target: target, day: "20130803", 
          lat: 1, lon: 2, rad: 50, info: info(['2013-08-02 7:49:28 UTC', '2013-08-02 10:45:36 UTC'], ['2013-08-02 11:49:28 UTC', '2013-08-02 18:45:36 UTC']), data: {'timezone' => +1}
        )
      end

      it 'returns the position' do
        expect(subject.office).to eq({:latitude=>1, :longitude=>2, :radius=>50})
      end
    end
  end
end
