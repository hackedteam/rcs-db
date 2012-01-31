require_relative 'single_evidence'

module RCS
module ChatProcessing
  extend SingleEvidence
  
  def process
    puts "CHAT: #{@info[:data]}"
  end

  def type
    :chat
  end
end # DeviceProcessing
end # RCS
