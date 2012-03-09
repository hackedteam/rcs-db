require_relative 'single_evidence'

module RCS
module ApplicationProcessing
  extend SingleEvidence

  def type
    :application
  end
end # ApplicationProcessing
end # DB
