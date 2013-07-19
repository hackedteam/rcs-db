class ConnectorQueue
  include Mongoid::Document
  extend RCS::Tracer

  field :cids,  as: :connector_ids, type: Array,    default: []
  field :d,     as: :data,          type: Hash,     default: {}

  store_in collection: 'connector_queue'

  validates_presence_of :data

  index connector_ids: 1

  scope :with_connector, lambda { |connector| where(connector_ids: connector.id) }

  def complete(connector)
    connector_ids.reject! { |id| id == connector.id }
    save!
  end

  def self.size
    all.count
  end

  def self.take
    first
  end

  def connectors
    Connector.any_in(id: connector_ids)
  end

  def keep?
    connectors.where(keep: true).count > 0
  end

  def self.push_evidence(connectors, target, evidence)
    fullpath = target.path + [evidence.aid]
    data = {evidence_id: evidence.id, target_id: target.id, path: fullpath}
    push(connectors, data)
  end

  def self.push(connectors, data)
    connectors = [connectors].flatten
    connector_ids = connectors.map(&:id)
    trace :debug, "Adding to ConnectorQueue: #{connector_ids}, #{data.inspect}"
    attributes = {connector_ids: connector_ids, data: data}
    create!(attributes)
  end
end
