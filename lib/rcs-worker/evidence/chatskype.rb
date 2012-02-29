require_relative 'single_evidence'

module RCS
module ChatskypeProcessing
  extend SingleEvidence
  
  def process
    puts "CHAT: #{self[:data]}"
  end
  
  def type
    :chat
  end
end # ChatskypeProcessing
end # RCS
