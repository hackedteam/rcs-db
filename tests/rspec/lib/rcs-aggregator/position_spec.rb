require 'spec_helper'
require_db 'db_layer'
require_db 'position/point'
require_aggregator 'position'

class Geotest
  include Mongoid::Document

  field :position, type: Array

  index({position: "2dsphere"})
end

module RCS
module Aggregator

describe PositionAggregator do
  before { turn_off_tracer }

  use_db

  it 'this is a test for geo_search' do

    Geotest.create_indexes

    g1 = Geotest.create!(position: [9.5939346, 45.5353563])
    g2 = Geotest.create!(position: [9.5945033, 45.5351362])
    g3 = Geotest.create!(position: [9.5936141, 45.5353538])

    p1 = RCS::DB::Point.new(lat: 45.5353563, lon: 9.5939346, r: 100)
    p2 = RCS::DB::Point.new(lat: 45.5351362, lon: 9.5945033, r: 40)
    p3 = RCS::DB::Point.new(lat: 45.5353538, lon: 9.5936141, r: 45)

    hr = RCS::DB::Point::EARTH_RADIUS * 1000

    dist = 50

    f1 = Geotest.geo_near([9.5939346, 45.5353563]).spherical.max_distance(dist / hr).distance_multiplier(hr * Math::PI / 180.0).to_a
    f2 = Geotest.geo_near([9.5945033, 45.5351362]).spherical.max_distance(dist / hr).distance_multiplier(hr * Math::PI / 180.0).to_a
    f3 = Geotest.geo_near([9.5936141, 45.5353538]).spherical.max_distance(dist / hr).distance_multiplier(hr * Math::PI / 180.0).to_a

    binding.pry
  end

end


end
end
