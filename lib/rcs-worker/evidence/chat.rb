require_relative 'single_evidence'

module RCS
module ChatProcessing
  extend SingleEvidence

  def type
    :chat
  end
end # ChatProcessing
end # RCS
