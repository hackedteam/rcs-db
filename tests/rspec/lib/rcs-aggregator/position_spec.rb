require 'spec_helper'
require_db 'db_layer'
require_db 'position/point'
require_aggregator 'position'

class Geotest
  include Mongoid::Document

  field :name, type: String
  field :data, type: Hash, default: {}
  #field :position, type: Array

  index({"data.position" => "2dsphere"})
end

module RCS
module Aggregator

describe PositionAggregator do
  before { turn_off_tracer }

  use_db

  def deg_to_rad(deg)
    rad_per_deg = Math::PI / 180
    deg * rad_per_deg
  end

  def rad_to_deg(rad)
    rad * 180 / Math::PI
  end

  def meter_to_rad(meter)
    circ = 2 * Math::PI * Point::EARTH_RADIUS * 1000
    deg = meter * 360 / circ
    deg_to_rad(deg)
  end

  it 'this is a test for geo_search' do

    Geotest.create_indexes

    Geotest.create!(data: {peer: 'spurious'}, name: 'peer')

    g1 = Geotest.create!(data: {position: [9.5939346, 45.5353563]}, name: 'p1')
    g2 = Geotest.create!(data: {position: [9.5945033, 45.5351362]}, name: 'p2')
    g3 = Geotest.create!(data: {position: [9.5936141, 45.5353538]}, name: 'p3')
    g4 = Geotest.create!(data: {position: [9.6036141, 45.5353538]}, name: 'p4')
    g5 = Geotest.create!(data: {position: [9.5936141, 45.5453538]}, name: 'p5')

    p1 = Point.new(lat: 45.5353563, lon: 9.5939346, r: 100)
    p2 = Point.new(lat: 45.5351362, lon: 9.5945033, r: 40)
    p3 = Point.new(lat: 45.5353538, lon: 9.5936141, r: 45)
    p4 = Point.new(lat: 45.5353538, lon: 9.6036141, r: 45)
    p5 = Point.new(lat: 45.5453538, lon: 9.5936141, r: 45)

    d12 = p1.distance p2
    d13 = p1.distance p3
    d14 = p1.distance p4
    d15 = p1.distance p5

    d23 = p2.distance p3
    d24 = p2.distance p4
    d25 = p2.distance p5

    d34 = p3.distance p4
    d35 = p3.distance p5

    d45 = p4.distance p5

    hr = (Point::EARTH_RADIUS * 1000).to_f

    dist = 1000 / hr

    f1 = Geotest.geo_near([9.5939346, 45.5353563]).spherical.max_distance(dist).distance_multiplier(hr).to_a
    f2 = Geotest.geo_near([9.5945033, 45.5351362]).spherical.max_distance(dist).distance_multiplier(hr).to_a
    f3 = Geotest.geo_near([9.5936141, 45.5353538]).spherical.max_distance(dist).distance_multiplier(hr).to_a
    f4 = Geotest.geo_near([9.6036141, 45.5353538]).spherical.max_distance(dist).distance_multiplier(hr).to_a
    f5 = Geotest.geo_near([9.5936141, 45.5453538]).spherical.max_distance(dist).distance_multiplier(hr).to_a

    c1 = Geotest.within_circle(position: [[9.6036141, 45.5353538], 50])

    #len = f4.to_a[3].geo_near_distance

    #binding.pry
    pending "Implement this"
  end

end


end
end
