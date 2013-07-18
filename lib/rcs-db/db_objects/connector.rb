require 'mongoid'
require 'rcs-common/trace'
require_relative 'item'

class Connector
  extend RCS::Tracer
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  TYPES = ['JSON', 'XML', 'ARCHIVE']

  field :enabled, type: Boolean
  field :name, type: String
  field :type, type: String, default: TYPES.first
  field :dest, type: String
  field :raw, type: Boolean
  field :keep, type: Boolean, default: true
  field :path, type: Array

  store_in collection: 'connectors'

  index enabled: 1
  index keep: 1

  validates_inclusion_of :type, in: TYPES
  validate :validate_operation_when_archive, on: :create

  before_destroy :check_used

  # Scope: only enabled connectors
  scope :enabled, where(enabled: true)

  # Scope: only enabled and matching collectors
  def self.matching(evidence)
    enabled.select { |connector| connector.match?(evidence) }
  end

  # If the type is archive, the path should be an operation
  def validate_operation_when_archive
    return if type != 'ARCHIVE'
    return if path.blank?
    if path.size != 1 or ::Item.operations.where(_id: path.first).empty?
      errors.add(:invalid, "An archive connector should match only operations")
    end
  end

  def check_used
    if queued_count > 0
      raise "The connector #{name} cannot be deleted now"
    end
  end

  def delete_if_item(id)
    return unless path.include?(id)
    trace :debug, "Deleting Connector because it contains #{id}"
    destroy
  end

  def update_path(id, path)
    return if self.path.last != id
    trace :debug, "Updating Connector because it contains #{id}"
    update_attributes! path: path
  end

  def match?(evidence)
    # Blank path means everything
    return true if path.blank?

    agent = ::Item.find(evidence.aid)
    # The path of an agent does not include itself, add it to obtain the full path
    agent_path = agent.path + [agent._id]
    # Check if the agent path is included in the path
    (agent_path & path) == path
  end

  def queued_count
    ConnectorQueue.with_connector(self).count
  end
end
