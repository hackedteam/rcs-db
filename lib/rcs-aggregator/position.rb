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
    #TODO: implement this

    lat = params[:data][:position][:latitude]
    lon = params[:data][:position][:longitude]

    location = [lon, lat]

    hr = RCS::DB::Point::EARTH_RADIUS * 1000

    existing = Aggregate.target(target_id).geo_near(location).max_distance(50 / hr).distance_multiplier(hr * Math::PI / 180.0).first

    if existing
      old = RCS::DB::Point.new(lat: existing.position[1], lon: existing.position[0], r: existing.data['position']['radius'])
      new = RCS::DB::Point.new(lat: lat, lon: lon, r: params[:data][:position][:radius])

      geo_distance = existing.geo_near_distance
      my_distance = new.distance(old)
    end

    binding.pry

    params[:position] = location

    return existing if existing

    # find the existing aggregate or create a new one
    Aggregate.target(target_id).find_or_create_by(params)
  end

end

end
end