require_relative 'single_evidence'

module RCS
module ChatoldProcessing
  extend SingleEvidence

  def type
    :chat
  end
end # ChatoldProcessing

module ChatProcessing
  extend SingleEvidence

  def type
    :chat
  end
end # ChatProcessing

end # RCS
