#
#  Module for handling position evidence
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class Position
  include Tracer
  extend Tracer

  class << self

    def save_last_position(entity, evidence)
      return if evidence[:data]['latitude'].nil? or evidence[:data]['longitude'].nil?

      entity.last_position = {latitude: evidence[:data]['latitude'].to_f,
                              longitude: evidence[:data]['longitude'].to_f,
                              time: evidence[:da],
                              accuracy: evidence[:data]['accuracy'].to_i}
      entity.save

      trace :info, "Saving last position for #{entity.name}: #{entity.last_position.inspect}"
    end

  end

end

end
end

