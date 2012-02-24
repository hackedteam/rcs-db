require_relative 'single_evidence'

module RCS
module SocialProcessing
  extend SingleEvidence

  def process
    puts "SOCIAL: #{@info[:data]}"
  end

  def type
    :chat
  end
end # SocialProcessing
end # RCS
