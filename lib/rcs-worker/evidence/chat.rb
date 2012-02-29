require_relative 'single_evidence'

module RCS
module ChatProcessing
  extend SingleEvidence
  
  def process
    puts "CHAT: #{self[:data]}"
  end

  def type
    :chat
  end
end # ChatProcessing
end # RCS
