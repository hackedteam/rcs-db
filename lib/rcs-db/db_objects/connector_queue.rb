require_relative 'connector'

class ConnectorQueue
  include Mongoid::Document
  extend RCS::Tracer
  include RCS::Tracer

  field :cid,   as: :connector_id,  type: Moped::BSON::ObjectId
  field :d,     as: :data,          type: Hash, default: {}
  field :s,     as: :scope,         type: String

  store_in collection: 'connector_queue'

  validates_presence_of  :data
  validates_presence_of  :connector_id
  validates_presence_of  :scope

  index({connector_id: 1, scope: 1})

  scope :with_connector, lambda { |connector| where(connector_id: connector.id) }

  after_destroy :evidence_destroy_countdown

  def evidence_destroy_countdown
    return unless evidence
    return unless evidence['destroy_countdown']

    if evidence.inc(:destroy_countdown, -1) <= 0
      trace :debug, "Destroying evidence #{evidence.id} because of destroy countdown reached"
      evidence.destroy
    end
  end

  def evidence
    @evidence ||= begin
      return unless data['target_id']
      ::Evidence.collection_class(data['target_id']).where(id: data['evidence_id']).first
    end
  end

  def connector
    @connector ||= Connector.where(id: connector_id).first
  end

  def to_s
    "<#ConnectorQueue #{id}: scope={#{scope}} connector_id=#{connector_id}, data=#{data.inspect}>"
  end

  def self.size
    all.count
  end

  def self.take(scope)
    where(scope: scope).first
  end

  def self.push_evidence(connector, target, evidence)
    fullpath = [target.path.first, target.id, evidence.aid]
    data = {evidence_id: evidence.id, target_id: target.id, path: fullpath}
    push(connector, data)
  end

  def self.push(connector, data)
    trace :debug, "Adding to ConnectorQueue: #{connector.id}, #{data.inspect}"
    scope = connector.archive? ? connector.dest : 'default'
    attributes = {connector_id: connector.id, data: data, scope: scope}
    create!(attributes)
  end

  def self.scopes
    distinct(:scope)
  end
end
