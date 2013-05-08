require 'spec_helper'
require_db 'position/point'

module RCS
module DB

describe Point do

  it 'should have accessors' do
    point = Point.new
    point.should respond_to :lat
    point.should respond_to :lon
    point.should respond_to :r
    point.should respond_to :time
    point.should respond_to :start
    point.should respond_to :end
  end

  it 'should initialize to default values' do
    point = Point.new
    point.time.should eq point.start
    point.end.should eq point.start
    point.lat.should eq 0.0
    point.lon.should eq 0.0
    point.r.should be Point::MIN_RADIUS
  end

  it 'should initialize correctly' do
    now = Time.now
    expected = {lat: 45.12345, lon: 9.12345, r: 100, time: now}
    point = Point.new(expected)
    point.lat.should eq expected[:lat]
    point.lon.should eq expected[:lon]
    point.r.should eq expected[:r]
    point.time.should eq expected[:time]
  end

  it 'should be comparable with other points' do
    now = Time.now
    p1 = Point.new(lat: 45.12345, lon: 9.12345, r: 100, time: now)
    p2 = Point.new(lat: 45.12345, lon: 9.12345, r: 100, time: now)

    p1.should eq p2
  end

  it 'should not accept invalid time' do
    lambda {Point.new(time: 34)}.should raise_error
  end

  it '#to_s should print with it' do
    time = Time.now
    a = Point.new({lat: 123, lon: 456, r: 10, time: time, start: time, end: time})

    output = a.to_s
    expected = "#{a.lat} #{a.lon} #{a.r} - #{a.time} (#{a.start} #{a.end})"

    output.should eq expected
  end

  it 'should have a minimum radius' do
    point = Point.new({r: 0})
    point.r.should eq Point::MIN_RADIUS

    point = Point.new({r: -10})
    point.r.should eq Point::MIN_RADIUS
  end

  it 'should detect identical points (with different time)' do
    a = Point.new({lat: 123, lon: 456, r: 10, time: Time.now})
    b = Point.new({lat: 123, lon: 456, r: 10, time: Time.now})
    c = Point.new({lat: 123, lon: 789, r: 10, time: Time.now})
    a.same_point?(b).should be true
    b.same_point?(a).should be true

    a.same_point?(c).should be false
    b.same_point?(c).should be false
  end

  it 'should intersect the same point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    a.intersect?(b).should be true
  end

  it 'should intersect bigger point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 50})
    a.intersect?(b).should be true
  end

  it 'should intersect points that are intersecting' do
    a = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    b = Point.new({lat: 45.4768005, lon: 9.1917216, r: 5})
    a.intersect?(b).should be true

    a = Point.new({lat: -45.4765921521739, lon: -9.19198076086957, r: 35})
    b = Point.new({lat: -45.4768005, lon: -9.1917216, r: 5})
    a.intersect?(b).should be true

    a = Point.new({lat: 0, lon: 0, r: 1000})
    b = Point.new({lat: 0, lon: 0.01, r: 1000})
    a.intersect?(b).should be true
  end

  it 'should intersect near points' do
    a = Point.new({lat: 45.5353563, lon: 9.5939346, r: 30})
    b = Point.new({lat: 45.5351362, lon: 9.5945033, r: 40})
    c = Point.new({lat: 45.5353538, lon: 9.5936141, r: 45})
    a.intersect?(b).should be true
    b.intersect?(c).should be true
    c.intersect?(a).should be true
  end

  it 'should not intersect distant points' do
    a = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    b = Point.new({lat: 45.5354705, lon: 9.5936281, r: 40})
    a.intersect?(b).should be false

    a = Point.new({lat: 0, lon: 0, r: 100})
    b = Point.new({lat: 1, lon: 1, r: 100})
    a.intersect?(b).should be false
  end

  it 'should intersect tanget point' do
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i

    # the two circles are tangent each other
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 1, r: meridians - a.r})
    a.intersect?(b).should be true

    # the two circles are tangent each other (111 meters of distance)
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0.001, r: meridians/1000 - a.r})
    a.intersect?(b).should be true
  end

  it 'should intersect not intersecting points but close enough' do
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i

    # the two circles does not intersect but we use approximation (INTERSECT_DELTA)
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 1, r: meridians - a.r - 10})
    a.intersect?(b).should be true

    # the two circles does not intersect for 11 meters (111 meters of distance)  10%
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0.001, r: 50})
    a.intersect?(b).should be true

    # the two circles does not intersect for 21 meters (111 meters of distance)  19%
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0.001, r: 40})
    a.intersect?(b).should be true

    # the two circles does not intersect for 31 meters (111 meters of distance)  27%
    a = Point.new({lat: 0, lon: 0, r: 40})
    b = Point.new({lat: 0, lon: 0.001, r: 40})
    a.intersect?(b).should be false
  end

  it 'should check overlapped the same point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    Point.overlapped?(a, b).should be true
  end

  it 'should check overlapped bigger point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 100})
    Point.overlapped?(a, b).should be true
  end

  it 'should check overlapped point' do
    a = Point.new({lat: 0, lon: 0, r: 1500})
    b = Point.new({lat: 0, lon: 0.01, r: 10})
    Point.overlapped?(a, b).should be true
  end

  it 'should overlap the same point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    a.overlap?(b).should be true
    b.overlap?(a).should be true
  end

  it 'should overlap larger point' do
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 100})
    b.overlap?(a).should be true
    a.overlap?(b).should be false
  end

  it 'should overlap other point' do
    a = Point.new({lat: 0, lon: 0, r: 1500})
    b = Point.new({lat: 0, lon: 0.01, r: 10})
    a.overlap?(b).should be true
    b.overlap?(a).should be false
  end

  it 'should calculate distance at the north pole' do
    a = Point.new({lat: 90, lon: 0})
    b = Point.new({lat: 90, lon: 45})
    a.distance(b).should be 0
  end

  it 'should calculate distance at the south pole' do
    a = Point.new({lat: -90, lon: 0})
    b = Point.new({lat: -90, lon: 45})
    a.distance(b).should be 0
  end

  it 'should calculate distance between two meridians' do
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i
    a = Point.new({lat: 0, lon: 0})
    b = Point.new({lat: 0, lon: 1})
    a.distance(b).should eq meridians
  end

  it 'should calculate the distance between two parallels' do
    # distance between two parallels varies between 110.57 and 111.69 km

    # at the equator
    parallels = 110574
    a = Point.new({lat: 0, lon: 0})
    b = Point.new({lat: 1, lon: 0})
    a.distance(b).should eq parallels

    # at the pole
    parallels = 111693
    a = Point.new({lat: 89, lon: 0})
    b = Point.new({lat: 90, lon: 0})
    a.distance(b).should eq parallels
  end

  it 'should detect similar points (overlapping)' do
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0, r: 100})
    a.similar_to?(b).should be true
    a.similar_to?(a).should be true
  end

  it 'should detect similar points (intersecting)' do
    a = Point.new({lat: 45.5353563, lon: 9.5939346, r: 30})
    b = Point.new({lat: 45.5351362, lon: 9.5945033, r: 40})
    c = Point.new({lat: 45.5353538, lon: 9.5936141, r: 45})
    a.similar_to?(b).should be true
    b.similar_to?(a).should be true
    a.similar_to?(c).should be true
    c.similar_to?(a).should be true
    b.similar_to?(c).should be true
    c.similar_to?(b).should be true
  end

  it 'should not detect as similar tanget points' do
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i
    # the two circles are tangent each other
    a = Point.new({lat: 0, lon: 0, r: meridians / 2})
    b = Point.new({lat: 0, lon: 1, r: meridians / 2})
    a.similar_to?(b).should be false
  end

  it 'should not detect as similar not intersecting points' do
    a = Point.new({lat: 0, lon: 0, r: 100})
    b = Point.new({lat: 1, lon: 1, r: 100})
    a.similar_to?(b).should be false
  end

  it 'should extract the best similar point' do
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0, r: 100})
    Point.best_similar(a, b).should be a
  end

  it 'should extract the best similar from intersecting points' do
    a = Point.new({lat: 45.5353563, lon: 9.5939346, r: 30})
    b = Point.new({lat: 45.5351362, lon: 9.5945033, r: 40})
    c = Point.new({lat: 45.5353538, lon: 9.5936141, r: 45})
    Point.best_similar(a, b).should be a
    Point.best_similar(b, c).should be b
    Point.best_similar(a, c).should be a

    Point.best_similar(a, b, c).should be a
  end

  it 'should extract the best similar from a group (with a very small point)' do
    a = Point.new({lat: 45.4768394, lon: 9.1919074, r: 15})
    b = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    c = Point.new({lat: 45.4768005, lon: 9.1917216, r: 5})
    d = Point.new({lat: 45.4765977798742, lon: 9.19193527672956, r: 35})
    e = Point.new({lat: 45.4765854782609, lon: 9.19197047826087, r: 66})
    f = Point.new({lat: 45.4765925952381, lon: 9.19200482539683, r: 35})
    g = Point.new({lat: 45.4765972446043, lon: 9.19200901438849, r: 35})

    # the best is c, but it's too precise, use the minimum radius
    expected = Point.new({lat: 45.4768005, lon: 9.1917216, r: Point::MINIMUM_SIMILAR_RADIUS})
    result = Point.best_similar(a, b, c, d, e, f, g)

    result.lat.should eq expected.lat
    result.lon.should eq expected.lon
    result.r.should eq expected.r
  end

  it 'should extract the best similar (first in time) if they have same radius' do
    a = Point.new({lat: 45.4768394, lon: 9.1919074, r: 20, time: Time.now})
    b = Point.new({lat: 45.4768005, lon: 9.1917216, r: 20, time: Time.now + 1})

    # the first one (in time) must win
    Point.best_similar(a, b).should be a

    # invert the time
    b.time -= 10

    Point.best_similar(a, b).should be b
  end

  it 'should not extract best similar from not intersecting points' do
    a = Point.new({lat: 0, lon: 0, r: 100})
    b = Point.new({lat: 1, lon: 1, r: 100})
    c = Point.new({lat: 0, lon: 0.0001, r: 100})
    Point.best_similar(a, b).should be_nil
    Point.best_similar(a, b, c).should be_nil
  end

  it 'should detect near points' do
    a = Point.new({lat: 45.5353563, lon: 9.5939346, r: 30})
    b = Point.new({lat: 45.5351362, lon: 9.5945033, r: 40})
    a.near?(b).should be true

    a = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    b = Point.new({lat: 45.4768005, lon: 9.1917216, r: 5})
    a.near?(b).should be true
  end

  it 'should detect distant points' do
    meridians = Point::EARTH_EQUATOR / 360 * 1000
    meter = 1.0 / meridians
    a = Point.new({lat: 0, lon: 0, r: Point::NEAR_DISTANCE})
    b = Point.new({lat: 0, lon: meter * (Point::NEAR_DISTANCE + 50), r: Point::NEAR_DISTANCE})
    a.near?(b).should be false
  end

end

end
end
