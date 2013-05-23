#
#  Emit positions where the target is staying provided the list of all the positions
#

require 'rcs-common/trace'
require 'base64'

require_relative 'point'

module RCS
module DB

# the idea here is to detect if the target is moving or not.
# to achieve this, we take a buffer of N element and check if they
# intersect each other. until they intersect, the target is staying in the
# same place. If a new point arrives that does not intersect, the target
# has started moving.
# we also have a filter to yield only place with a minimum time of staying
# we also detect data holes to avoid saying tha the target was staying in
# a place if we have no data
#
# every emitted Point has a starting and end time representing the time frame
# in which the target was there

class Positioner

  # buffer size, after N points in the same place
  WINDOW_SIZE = 5
  # minimum time for a place to be considered good (in seconds)
  MIN_TIME_IN_A_PLACE = 10*60
  # maximum radius for a place to be considered good (in meters)
  MAX_RADIUS_FOR_PLACE = 500
  
  def initialize(params = {})
    @window_size = params[:win] || WINDOW_SIZE
    @min_time = params[:time] || MIN_TIME_IN_A_PLACE
    @max_radius = params[:radius] || MAX_RADIUS_FOR_PLACE
    @similar = params[:similar] || nil
    reset
  end

  def reset
    @point_buffer = []
    @curr_point = nil
    @start = nil
  end

  def dump
    Base64.encode64(Marshal.dump(self))
  end

  def self.new_from_dump(status)
    Marshal.load(Base64.decode64(status))
  end

  def emit_and_reset
    #binding.pry
    if @point_buffer.first and @curr_point
      # force the start point even if the buffer is not full
      # take the minimum from the current and the first in the buffer
      @start ||= [@point_buffer.first, @curr_point].min {|a,b| a.time <=> b.time}
      # emit the current position (truncated now)
      yield emit_current if within_max_radius?
    end
    # restart the counters
    reset
  end

  def feed(point)

    unless @point_buffer.empty?

      # all the points in the buffer intersect the new point
      all = @point_buffer.all? {|curr| point.intersect?(curr) }
      # all + the current position (minimized)
      all &= point.intersect?(@curr_point) if @curr_point

      # find the more accurate point in the buffer (minimum radius)
      min_point = @point_buffer.min {|a,b| a.r <=> b.r}

      # update the current position to the more accurate if needed
      @curr_point = min_point if all and (@curr_point.nil? or @curr_point.r > min_point.r)

      # set the staying flag if the buffer is full
      staying = (all and full?)

      # save the first position matching the criteria (used to emit the starting time)
      # this represent the first point in the staying place
      if staying and not @start
        @start = @point_buffer.first
      end

=begin
      action = staying ? "STAY #{@curr_point.lat} #{@curr_point.lon} #{@curr_point.r}" : 'move'
      action = '???' if all and (@point_buffer.size != WINDOW_SIZE)
      puts "#{Time.at(point.time)} |#{@point_buffer.size}|  #{all}  \t\t##  #{action}"
=end

      # empty the buffer if the target is moving OR
      # if the difference between the new point is greater that the whole window (detect a data hole)
      if (not all) or (full? and hole?(point))
        # the target is moving (from a previously recorded stay position), emit the 'staying' period
        # filtering on the minimum time in a place
        if @start and minimum_time? and within_max_radius?
          out = emit_current

          # check for already outputted points in the history
          # if the similar manager is not provided, output all the points
          out = @similar.find(out) if @similar

          yield out
        end
        # reset the buffer
        reset
      end
    end

    # add the point to the buffer (keep the buffer on size)
    @point_buffer << point
    @point_buffer.shift if @point_buffer.size > @window_size
  end

  private

  def emit_current
    Point.new({time: @start.time,
               start: @start.time,
               end: @point_buffer.last.time,
               lat: @curr_point.lat,
               lon: @curr_point.lon,
               r: @curr_point.r})
  end

  def full?
    @point_buffer.size == @window_size
  end

  def hole?(point)
    point.time - @point_buffer.last.time > @point_buffer.last.time - @point_buffer.first.time
  end

  def minimum_time?
    @point_buffer.last.time - @start.time >= @min_time
  end

  def within_max_radius?
    @curr_point.r <= @max_radius
  end

end


end #DB::
end #RCS::