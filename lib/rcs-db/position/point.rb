#
#  Handling of points on the map (lat, lon, radius)
#

require 'rcs-common/trace'
require 'rvincenty'

module RCS
module DB


class Point
  
  attr_accessor :lat, :lon, :r, :time, :start, :end

  # to obtain 2sigma on gps precision = 80%
  # http://en.wikipedia.org/wiki/Standard_deviation
  INTERSECT_DELTA = 1.281552
  # the distance to be considered near (in meters)
  NEAR_DISTANCE = 500
  # minimum radius of a point for the best_similar method
  MINIMUM_SIMILAR_RADIUS = 20
  # minimum radius assigned for invalid values
  MIN_RADIUS = 30
  # Earth radius in kilometers
  EARTH_RADIUS = 6371
  # Earth equator in kilometers
  EARTH_EQUATOR = 40075.017

  def initialize(params = {})
    self.time = Time.now
    self.start = self.time
    self.end = self.start
    self.lat = 0.0
    self.lon = 0.0
    self.r = 0
    
    if params[:time]
      self.time = params[:time] 
      self.start = params[:time] 
    end
    self.start = params[:start] if params[:start]
    self.end = params[:end] if params[:end]
    self.lat = params[:lat] if params[:lat]
    self.lon = params[:lon] if params[:lon]
    self.r = params[:r] if params[:r]
    
    # set a minimum radius
    self.r = MIN_RADIUS if r <= 0
  end
  
  def to_s
    "#{self.lat} #{self.lon} #{self.r} - #{self.time} (#{self.start} #{self.end})"
  end
  
=begin
  # Haversine formula to calculate the distance between two coordinates
  def distance(point)
    a = [self.lat, self.lon]
    b = [point.lat, point.lon]

    rad_per_deg = Math::PI/180  # PI / 180
    rm = EARTH_RADIUS * 1000

    # Delta, converted to rad
    dlon_rad = (b[1] - a[1]) * rad_per_deg  
    dlat_rad = (b[0] - a[0]) * rad_per_deg

    lat1_rad, lon1_rad = a.map! {|i| i * rad_per_deg }
    lat2_rad, lon2_rad = b.map! {|i| i * rad_per_deg }

    a = Math.sin(dlat_rad/2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2)**2
    c = 2 * Math.asin(Math.sqrt(a))

    # distance in meters
    (rm * c).to_i
  end
=end

  # Vincenty formula to calculate the distance between two coordinates
  def distance(point)
    a = [self.lat, self.lon]
    b = [point.lat, point.lon]

    RVincenty.distance(a, b).to_i
  end

  def intersect?(point)
    # two circles intersect if the distance between the centers is 
    # less than the sum of the two radius

    # add al little delta to the radius since that radius represent the 65% of probability to be within
    distance(point) < self.r * INTERSECT_DELTA + point.r * INTERSECT_DELTA
  end

  def overlap?(point)
    # a circle overlaps another if the radius is bigger than
    # the distance between the centers plus the radius of the second point
    self.r >= self.distance(point) + point.r
  end

  def self.overlapped?(a, b)
    # two circles overlap if the distance between the centers
    # plus the minimum radius is less than the bigger radius
    a.distance(b) + [a.r, b.r].min <= [a.r, b.r].max
  end

  def near?(b)
    distance(b) <= NEAR_DISTANCE
  end

  def similar_to?(b)
    # to circles are considered similar if:
    # - they overlap
    # - they intersect but are near each other
    return true if self.class.overlapped?(self, b)

    return true if intersect?(b) and near?(b)

    return false
  end

  def self.best_similar(*points)
    # to find the best similar, just check if they are all similar
    return nil if not points.combination(2).all? {|c| c.first.similar_to? c.last}

    # and then take the smaller (more precise) one
    best = points.min_by {|x| x.r}

    # adjust the radius to avoid too precise points
    best.r = MINIMUM_SIMILAR_RADIUS if best.r < MINIMUM_SIMILAR_RADIUS

    return best
  end

end


end #DB::
end #RCS::