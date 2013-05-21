require 'active_support/concern'
require_relative 'point'

module RCS
module DB

  module Proximity
    extend ActiveSupport::Concern

    EARTH_RADIUS_IN_METERS = (Point::EARTH_RADIUS * 1000).to_f

    module ClassMethods
      def positions_within position, distance = nil
        # distance to search similar points is the same as the NEAR_DISTANCE used in #similar_to?
        # this distance has to be calculated in radians
        distance = meter_to_radius(distance || Point::NEAR_DISTANCE)

        # the location array is used by the 2dSphere index
        location_ary = [position[:longitude], position[:latitude]]

        criteria = respond_to?(:positions) && positions || self

        criteria.geo_near(location_ary).
                 spherical.
                 max_distance(distance).
                 distance_multiplier(EARTH_RADIUS_IN_METERS)
      end

      private

      def meter_to_radius meters
        meters / EARTH_RADIUS_IN_METERS
      end
    end
  end

end
end
