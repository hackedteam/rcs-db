require 'rcs-common/trace'
require 'date'

module RCS
  module Intelligence
    class Position

      # Infer the home and the office of a given target.
      class Infer
        attr_reader :target, :from, :to

        MIN_DAYS = 3
        HALF_HOUR = 0.5
        HOME_TIMESLOT = [(22..23.5), (0..6)]
        WORKDAY_TIMESLOT = [(8..19)]

        def initialize(target, week_or_datetime)
          @target = target
          @from, @to = week_bounds(week_or_datetime)
        end

        # Find the first and the last day of the week
        # the given datetime belong to
        def week_bounds(week_or_datetime)
          if week_or_datetime.respond_to?(:to_date)
            date = week_or_datetime.to_date
            year = date.cwyear
            week = date.cweek
          else
            year = Time.now.utc.year
            week = week_or_datetime.to_i
          end

          monday = DateTime.commercial(year, week, 1).to_time.utc
          sunday = monday + 3600 * 24 * 6

          [monday, sunday].map { |d| d.strftime('%Y%m%d') }
        end

        def each_aggregate
          Aggregate.target(target).positions.between(day: from..to).each do |aggregate|
            next unless aggregate.info.respond_to?(:each)
            yield(aggregate)
          end
        end

        # Floor the datetime to the prev half hour. Example:
        # 2013-07-29 22:49:28 UTC => 2013-07-29 22:30:00 UTC
        # 2013-07-29 22:10:08 UTC => 2013-07-29 22:00:00 UTC
        def normalize_datetime(datetime)
          minutes_to_shift = datetime.min >= 30 ? datetime.min - 30 : datetime.min
          datetime = datetime - (minutes_to_shift * 60) - datetime.sec
        end

        # Returns an hash. Keys are cwdays (eg. Mon is 1, Thu is 2, etc.)
        # Values are time intervals, eg. [20, 20.5, 21]. 20 represents the interval from 8pm to 8:30pm,
        # 20.5 the one from 8:30pm to 9pm.
        def normalize_interval(interval, timezone = 0)
          return unless interval.respond_to?(:[])

          start, stop = interval['start'], interval['end']
          shift = timezone.to_i * 3600

          return unless start && stop
          return if start > stop

          start = normalize_datetime(start + shift)
          stop = normalize_datetime(stop + shift)

          results = {}

          while start <= stop do
            results[start.to_date.cwday] ||= []
            results[start.to_date.cwday] << (start.min == 0 ? start.hour : start.hour + HALF_HOUR)
            start += 30 * 60
          end

          results
        end

        # Returns an hash like:
        # {
        #   1 => {
        #       14 => [{:latitude=>45.47354920000001, :longitude=>9.232277999999999, :radius=>30}],
        #       14.5 => [{:latitude=>45.47354920000001, :longitude=>9.232277999999999, :radius=>30}]
        #   }
        # }
        def week_distribution
          results = {}

          each_aggregate do |aggregate|
            aggregate.info.each do |interval|
              interval = normalize_interval(interval, aggregate.data['timezone'])

              next unless interval

              interval.each do |day, spans|
                results[day] ||= {}
                spans.each { |span|
                  results[day][span] ||= []
                  results[day][span] << aggregate.position
                }
              end
            end
          end

          results
        end

        # Returns a list of couple POSITION, FREQUENCY. Example:
        # [
        #   [{:latitude=>45.47354920000001, :longitude=>9.232277999999999, :radius=>30}, 4],
        #   [{:latitude=>45.4806173, :longitude=>9.221273499999999, :radius=>30}, 42]
        # ]
        def group_and_count_positions_within(ranges)
          dist = week_distribution
          return [] if dist.keys.size < MIN_DAYS

          grouped = {}

          dist.each do |day, intervals|
            ranges.each do |range|
              intervals.each do |half_hour, positions|
                next if !range.include?(half_hour)
                positions.each { |p| grouped[p] ||= 0; grouped[p] += 1 }
              end
            end
          end

          grouped.sort_by { |key, value| value }
        end

        # Returns the most visited place in the given ranges.
        # Example: {:latitude=>45.4806173, :longitude=>9.221273499999999, :radius=>30}
        def most_visited_place(ranges)
          max_half_hour_per_week = ranges.inject(0) { |num, range| num += range.step(HALF_HOUR).size; num } * 7
          minimum_frequency = (35.0 / 100.0) * max_half_hour_per_week # 35%

          grouped = group_and_count_positions_within(ranges).last
          grouped[0] if grouped && grouped[1] > minimum_frequency
        end

        def home
          most_visited_place(HOME_TIMESLOT)
        end

        def office
          most_visited_place(WORKDAY_TIMESLOT)
        end
      end
    end
  end
end
