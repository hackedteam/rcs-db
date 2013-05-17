#
#  Module for handling position aggregations
#

module RCS
module Aggregator

class PositionAggregator

  def self.extract(ev)
    data = []

    # TODO: implement this!!!
    data << {type: 'position',
             point: {latitude: ev.data['latitude'], longitude: ev.data['longitude'], radius: ev.data['accuracy']},
             timeframe: {start: 1368090368, end: 1368091368}}

    return data
  end

  def self.find_similar_or_create_by(target_id, params)

    lat = params[:data][:position][1]
    lon = params[:data][:position][0]
    radius = params[:data][:radius]

    location = [lon, lat]

    hr = (Point::EARTH_RADIUS * 1000).to_f
    distance = Point::NEAR_DISTANCE / hr

    existing = nil

    Aggregate.target(target_id).geo_near(location).spherical.max_distance(distance).distance_multiplier(hr).each do |agg|
      old = agg.to_point
      new = Point.new(lat: lat, lon: lon, r: radius)

      return agg if old.similar_to? new
    end

    params[:position] = location

    # find the existing aggregate or create a new one
    Aggregate.target(target_id).find_or_create_by(params)
  end

end

end
end