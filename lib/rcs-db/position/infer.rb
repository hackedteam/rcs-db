require 'rcs-common/trace'
require 'date'

module RCS
  module DB
    module Position

      # Infer the home and the office of a given target.
      class Infer
        attr_reader :target, :from, :to

        MIN_DAYS = 3

        def initialize(target, week_or_datetime)
          @target = target
          @from, @to = week_bounds(week_or_datetime)
        end

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
        def normalize_interval(interval, timezone)
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
            results[start.to_date.cwday] << (start.min == 0 ? start.hour : start.hour + 0.5)
            start += 30 * 60
          end

          results
        end

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

        def group_positions(span_start, span_stop, hash, append = {})
          grouped = {}

          hash.each do |span, positions|
            next if span < span_start || span > span_stop
            positions.each { |p|
              grouped[p] ||= 0; grouped[p] += 1
              append[p] ||= 0; append[p] += 1
            }
          end

          grouped
        end

        def home
          dist = week_distribution
          return if dist.keys.size < MIN_DAYS

          grouped = {}

          dist.each { |day, positions|
            group_positions(22, 23.5, positions, grouped)
            group_positions(0, 6, positions, grouped)
          }

          most_visited = grouped.sort_by {|_key, value| value}.last
          most_visited[0] if most_visited && most_visited[1] > 38
        end

        def office
          dist = week_distribution
          return if dist.keys.size < MIN_DAYS

          grouped = {}

          dist.each { |day, positions| group_positions(8, 19, positions, grouped) }

          most_visited = grouped.sort_by {|_key, value| value}.last
          most_visited[0] if most_visited && most_visited[1] > 20
        end
      end

    end
  end
end
