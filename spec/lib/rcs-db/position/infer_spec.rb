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

  before do
    @day = day.strftime('%Y%m%d').to_i
    factory_create(:position_aggregate, target: target, day: @day + 0, lat: 1, lon: 2, rad: 50, info: info(['2013-07-29 13:49:28 UTC', '2013-07-29 17:45:36 UTC']), data: {'timezone' => +9})
    # factory_create(:position_aggregate, target: target, day: @day - 1, lat: 1, lon: 2, rad: 20)
    # factory_create(:position_aggregate, target: target, day: @day - 2, lat: 1, lon: 2, rad: 10)
    # factory_create(:position_aggregate, target: target, day: @day - 3, lat: 1, lon: 2, rad: 40)
    # factory_create(:position_aggregate, target: target, day: @day - 4, lat: 7, lon: 8, rad: 40)
    # factory_create(:position_aggregate, target: target, day: @day - 5, lat: 7, lon: 8, rad: 40)
    # factory_create(:position_aggregate, target: target, day: @day - 6, lat: 7, lon: 8, rad: 40)
  end

end
