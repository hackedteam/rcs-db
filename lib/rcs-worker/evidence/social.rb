require_relative 'single_evidence'

module RCS
module SocialProcessing
  extend SingleEvidence

  def type
    :chat
  end
end # SocialProcessing
end # RCS
