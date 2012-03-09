require_relative 'single_evidence'

module RCS
module PasswordProcessing
  extend SingleEvidence

  def type
    :password
  end
end # ApplicationProcessing
end # DB
