require 'mongoid'

#module RCS
#module DB

class OCRQueue
  include Mongoid::Document
  extend RCS::Tracer

  field :target_id, type: String
  field :evidence_id, type: String
  field :flag, type: Integer

  store_in :ocr_queue, capped: true, max: 100_000, size: 50_000_000


  def self.add(target_id, evidence_id)

    trace :debug, "Adding to OCR queue: #{target_id} #{evidence_id}"

  end

end

#end # ::DB
#end # ::RCS