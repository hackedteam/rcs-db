#
#  Module for handling position aggregations
#

module RCS
module Aggregator

class PositionAggregator

  def self.extract(ev)
    data = []

    # TODO: implement this!!!
    data << {type: 'position', point: {latitude: ev.data['latitude'], longitude: ev.data['longitude'], radius: ev.data['accuracy']}, time: {start: 1368090368, end: 1368091368}}

    return data
  end

  def self.find_similar(params)
    #TODO: implement this
    params
  end

end

end
end