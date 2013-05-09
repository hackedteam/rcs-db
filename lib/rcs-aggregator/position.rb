#
#  Module for handling position aggregations
#

module RCS
module Aggregator

class PositionAggregator

  def self.extract(ev)
    data = []

    # TODO: implement this!!!
    data << {type: 'position', point: {latitude: 45, longitude: 9, radius: 500}, time: {start: 1368090368, end: 1368091368}}

    return data
  end

end

end
end