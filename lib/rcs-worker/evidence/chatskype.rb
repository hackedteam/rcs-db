require_relative 'single_evidence'

module RCS
module ChatskypeProcessing
  extend SingleEvidence
  
  def process
    puts "CHAT: #{@info[:data]}"
  end
  
  def type
    :chat
  end
end # ChatskypeProcessing
end # RCS
