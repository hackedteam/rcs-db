#
#  Module for handling position aggregations
#

module RCS
module Aggregator

class PositionAggregator

  def self.extract(ev)
    data = []

    # TODO: implement this!!!
    data << {type: :position,
             point: {latitude: ev.data['latitude'], longitude: ev.data['longitude'], radius: ev.data['accuracy']},
             timeframe: {start: 1368090368, end: 1368091368}}

    return data
  end

  def self.find_similar_or_create_by(target_id, params)

    lat = params[:data][:position][1]
    lon = params[:data][:position][0]
    radius = params[:data][:radius]

    location = [lon, lat]

    # distance to search similar points is the same as the NEAR_DISTANCE used in #similar_to?
    # this distance has to be calculated in radians
    distance = Point::NEAR_DISTANCE

    # the idea here is:
    # search in the db for point near the current one
    # then check for similarity, if one is found, return the old one
    Aggregate.target(target_id).positions_within(location, distance).each do |agg|
      # convert aggregate to point
      old = agg.to_point
      new = Point.new(lat: lat, lon: lon, r: radius)

      # if similar, return the old point
      if old.similar_to? new
        if agg.day.eql? params[:day]
          return agg
        else
          # if the day is different, create a new one on current day, but same old position
          params[:data] = agg[:data]
          return Aggregate.target(target_id).create!(params)
        end
      end
    end

    # no previous match create a new one
    Aggregate.target(target_id).create!(params)
  end

end

end
end