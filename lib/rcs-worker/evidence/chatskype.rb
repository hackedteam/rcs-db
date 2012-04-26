require_relative 'single_evidence'

module RCS
module ChatskypeProcessing
  extend SingleEvidence

  def type
    :chat
  end
end # ChatskypeProcessing
end # RCS
