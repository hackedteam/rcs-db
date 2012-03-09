require_relative 'single_evidence'

module RCS
module FilecapProcessing
  extend SingleEvidence

  def type
    :file
  end
end # ApplicationProcessing
end # DB
