require_relative 'single_evidence'

module RCS
module InfoProcessing
  extend SingleEvidence

  def type
    :info
  end
end # ApplicationProcessing
end # DB
