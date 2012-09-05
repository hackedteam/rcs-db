#
# OCR processing module
#
# the evidence to be processed are equeued
#

require 'rcs-common/trace'

module RCS
module OCR

class Processor
  extend RCS::Tracer

  def self.run
    db = Mongoid.database
    coll = db.collection('ocr_queue')

    loop do
      if doc = coll.find_and_modify({query: {flag: 0}, update: {"$set" => {flag: 1}}})
        puts doc
      else
        puts "poll..."
        sleep 1
      end
    end

  end

end

end #OCR::
end #RCS::