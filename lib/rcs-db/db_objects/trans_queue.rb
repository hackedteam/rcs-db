require 'mongoid'

#module RCS
#module DB

class TransQueue
  include Mongoid::Document
  extend RCS::Tracer

  QUEUED = 0
  PROCESSED = 1

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer

  store_in :trans_queue, capped: true, max: 100_000, size: 50_000_000


  def self.add(target_id, evidence_id)

    trace :debug, "Adding to TRANSLATE queue: #{target_id} #{evidence_id}"

    TransQueue.create!({target_id: target_id.to_s, evidence_id: evidence_id.to_s, flag: QUEUED})
  end

end

#end # ::DB
#end # ::RCS