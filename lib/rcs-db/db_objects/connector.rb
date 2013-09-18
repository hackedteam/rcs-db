require 'mongoid'
require 'rcs-common/trace'
require_relative 'item'
require_relative '../archive_node'

class Connector
  extend RCS::Tracer
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  TYPES = ['LOCAL', 'REMOTE']
  FORMATS = ['JSON', 'XML', 'RCS']

  field :enabled, type: Boolean
  field :name, type: String
  field :type, type: String
  field :format, type: String
  field :dest, type: String
  field :keep, type: Boolean, default: true
  field :path, type: Array

  store_in collection: 'connectors'

  index(enabled: 1)
  index(keep: 1)
  index(type: 1)
  index(path: 1)
  index(type: 1, path: 1)

  validates_presence_of :dest
  validates_inclusion_of :type, in: TYPES
  validates_inclusion_of :format, in: FORMATS, if: :local?
  validate :validate_path_is_an_operation, on: :create, if: :remote?

  after_destroy :destroy_archive_node, if: :remote?
  after_save :setup_archive_node, if: lambda { remote? and enabled }

  # Scope: only enabled connectors
  scope :enabled, where(enabled: true)

  def validate_path_is_an_operation
    return if path.blank?
    if path.size != 1 or ::Item.operations.where(_id: path.first).empty?
      errors.add(:invalid, "An archive connector should match only operations")
    end
  end

  def archive_node
    return unless remote?
    @archive_node ||= RCS::DB::ArchiveNode.new(dest)
  end

  def defer(&block)
    Thread.new do
      Thread.current.abort_on_exception = true
      yield
    end
  end

  def setup_archive_node
    defer { archive_node.try(:setup!) }
  end

  def destroy_archive_node
    archive_node.try(:destroy)
  end

  def local?
    type == 'LOCAL'
  end

  def remote?
    type == 'REMOTE'
  end

  def delete_if_item(id)
    return unless path.include?(id)
    trace :debug, "Deleting Connector because it contains #{id}"
    destroy
  end

  def update_path(replace)
    trace :debug, "Updating connector #{id} path: #{replace.inspect}"
    replace.each { |position, value| path[position] = value }
    save
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

  def in_use?
    queued_count > 0
  end

  def queued_count
    ConnectorQueue.with_connector(self).count
  end
end
