require_relative 'single_evidence'

module RCS
module UrlProcessing
  extend SingleEvidence

  def type
    :url
  end
end # ApplicationProcessing
end # DB