require_relative '../helper'
require_db 'position/point'

module RCS
module DB

class PointTest < Test::Unit::TestCase

  def test_init
    point = Point.new
    assert_equal point.time, point.start
    assert_equal point.end, point.start
    assert_equal 0.0, point.lat
    assert_equal 0.0, point.lon
    assert_equal Point::MIN_RADIUS, point.r
  end

  def test_min_radius
    point = Point.new({r: 0})
    assert_equal Point::MIN_RADIUS, point.r

    point = Point.new({r: -10})
    assert_equal Point::MIN_RADIUS, point.r
  end

  def test_init_values
    now = Time.now
    expected = {lat: 45.12345, lon: 9.12345, r: 100, time: now}
    point = Point.new(expected)
    assert_equal expected[:lat], point.lat
    assert_equal expected[:lon], point.lon
    assert_equal expected[:r], point.r
    assert_equal expected[:time], point.time
  end

  def test_intersect_same
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    assert_true a.intersect? b
  end

  def test_intersect_bigger
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 50})
    assert_true a.intersect? b
  end

  def test_intersect_true
    a = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    b = Point.new({lat: 45.4768005, lon: 9.1917216, r: 5})
    assert_true a.intersect? b

    a = Point.new({lat: -45.4765921521739, lon: -9.19198076086957, r: 35})
    b = Point.new({lat: -45.4768005, lon: -9.1917216, r: 5})
    assert_true a.intersect? b

    a = Point.new({lat: 0, lon: 0, r: 1000})
    b = Point.new({lat: 0, lon: 0.01, r: 1000})
    assert_true a.intersect? b
  end

  def test_intersect_false
    a = Point.new({lat: 45.4765921521739, lon: 9.19198076086957, r: 35})
    b = Point.new({lat: 45.5354705, lon: 9.5936281, r: 40})
    assert_false a.intersect? b

    a = Point.new({lat: 0, lon: 0, r: 100})
    b = Point.new({lat: 1, lon: 1, r: 100})
    assert_false a.intersect? b

  end

  def test_intersect_tangent
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i

    # the two circles are tangent each other
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 1, r: meridians - a.r})
    assert_true a.intersect? b

    # the two circles are tangent each other (111 meters of distance)
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0.001, r: meridians/1000 - a.r})
    assert_true a.intersect? b
  end

  def test_intersect_not_intersecting_but_close_enough
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i

    # the two circles does not intersect but we use approximation (INTERSECT_DELTA)
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 1, r: meridians - a.r - 10})
    assert_true a.intersect? b

    # the two circles does not intersect for 11 meters (111 meters of distance)  10%
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0.001, r: 50})
    assert_true a.intersect? b

    # the two circles does not intersect for 21 meters (111 meters of distance)  19%
    a = Point.new({lat: 0, lon: 0, r: 50})
    b = Point.new({lat: 0, lon: 0.001, r: 40})
    assert_true a.intersect? b

    # the two circles does not intersect for 31 meters (111 meters of distance)  27%
    a = Point.new({lat: 0, lon: 0, r: 40})
    b = Point.new({lat: 0, lon: 0.001, r: 40})
    assert_false a.intersect? b
  end

  def test_overlapped_same
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    assert_true Point.overlapped? a, b
  end

  def test_overlapped_bigger
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 100})
    assert_true Point.overlapped? a, b
  end

  def test_overlapped
    a = Point.new({lat: 0, lon: 0, r: 1500})
    b = Point.new({lat: 0, lon: 0.01, r: 10})
    assert_true Point.overlapped? a, b
  end

  def test_overlap_same
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 10})
    assert_true a.overlap? b
    assert_true b.overlap? a
  end

  def test_overlap_bigger
    a = Point.new({lat: 0, lon: 0, r: 10})
    b = Point.new({lat: 0, lon: 0, r: 100})
    assert_true b.overlap? a
    assert_false a.overlap? b
  end

  def test_overlap
    a = Point.new({lat: 0, lon: 0, r: 1500})
    b = Point.new({lat: 0, lon: 0.01, r: 10})
    assert_true a.overlap? b
    assert_false b.overlap? a
  end

  def test_distance_meridians
    # distance between two meridians
    meridians = (Point::EARTH_EQUATOR / 360 * 1000).to_i
    a = Point.new({lat: 0, lon: 0})
    b = Point.new({lat: 0, lon: 1})
    assert_equal meridians, a.distance(b)
  end

  def test_distance_north_pole
    a = Point.new({lat: 90, lon: 0})
    b = Point.new({lat: 90, lon: 45})
    assert_equal 0, a.distance(b)
  end

  def test_distance_south_pole
    a = Point.new({lat: -90, lon: 0})
    b = Point.new({lat: -90, lon: 45})
    assert_equal 0, a.distance(b)
  end

end

end
end
