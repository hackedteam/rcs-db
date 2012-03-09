require_relative 'single_evidence'

module RCS
module KeylogProcessing
  extend SingleEvidence

  def type
    :keylog
  end
end # ApplicationProcessing
end # DB
