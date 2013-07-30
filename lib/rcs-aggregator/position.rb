#
#  Module for handling position aggregations
#

module RCS
module Aggregator

class PositionAggregator
  extend RCS::Tracer

  def self.minimum_time_in_a_position
    RCS::DB::Config.instance.global['POSITION_TIME']
  end

  def self.extract(target_id, ev)

    # check if the position is good
    return [] if ev.data['latitude'].nil? or ev.data['longitude'].nil?

    positioner_agg = Aggregate.target(target_id).find_or_create_by(type: :positioner, day: '0', aid: '0')

    min_time = minimum_time_in_a_position

    result = nil

    # load the positioner from the db, if already saved, otherwise create a new one
    if positioner_agg.data[ev.aid.to_s]
      begin
        #trace :debug, "Reloading positioner from saved status (#{ev.aid.to_s})"
        positioner = RCS::DB::Positioner.new_from_dump(positioner_agg.data[ev.aid.to_s]['positioner'])
      rescue Exception => e
        trace :warn, "Cannot restore positioner status, creating a new one..."
        positioner = RCS::DB::Positioner.new(time: min_time)
      end

      # check the day of the last position processed
      last_position_day = Time.at(positioner_agg.data[ev.aid.to_s]['last']).getutc.strftime('%Y%m%d')
      current_position_day = Time.at(ev.da).getutc.strftime('%Y%m%d')

      # if we detect that the day has changed, force the positioner to emit the point in the previous day
      if last_position_day != current_position_day
        positioner.emit_and_reset do |stay|
          result = stay
          trace :info, "Positioner has detected a change in the day, forcing output of a stay point: #{stay.to_s}"
        end
      end

    else
      trace :debug, "Creating a new positioner for #{ev.aid.to_s}"
      positioner = RCS::DB::Positioner.new(time: min_time)
    end

    trace :debug, "lat: #{ev.data['latitude'].to_f}, lon: #{ev.data['longitude'].to_f}, r: #{ev.data['accuracy'].to_i}"

    # create a point from the evidence
    point = Point.new(lat: ev.data['latitude'].to_f, lon: ev.data['longitude'].to_f, r: ev.data['accuracy'].to_i, time: ev.da)

    # feed the positioner with the point and take the result (if any)
    positioner.feed(point) do |stay|
      result = stay
      trace :info, "Positioner has detected a stay point: #{stay.to_s}"
    end

    # save the positioner status into the aggregate
    positioner_agg.data[ev.aid] = {positioner: positioner.dump, last: ev.da}
    positioner_agg.save

    # empty if not emitted
    return [] unless result

    # return the stay point
    return [{type: :position,
             time: result.end,
             point: {latitude: result.lat, longitude: result.lon, radius: result.r},
             timeframe: {start: result.start, end: result.end}}]
  end

  def self.find_similar_or_create_by(target_id, params)

    position = params[:data][:position]

    # extract the radius and don't save points that are too precise, enlarge it to the min similarity radius
    params[:data][:radius] = params[:data][:position][:radius]
    params[:data][:radius] = Point::MINIMUM_SIMILAR_RADIUS if params[:data][:radius] < Point::MINIMUM_SIMILAR_RADIUS

    # the idea here is:
    # search in the db for point near the current one
    # then check for similarity, if one is found, return the old one
    past = Aggregate.target(target_id).positions_within(position).to_a

    # sort the result by day in reverse order, so we get the most recent first
    past.sort_by! {|x| x.day}.reverse!

    # search if we have the same point in the past (starting from today)
    # return if found
    past.each do |agg|
      # convert aggregate to point
      old = agg.to_point
      new = Point.new(lat: position[:latitude], lon: position[:longitude], r: params[:data][:radius])

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
    params[:data][:position] = [params[:data][:position][:longitude], params[:data][:position][:latitude]]

    Aggregate.target(target_id).create!(params)
  end

end

end
end