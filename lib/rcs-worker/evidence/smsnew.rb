require_relative 'single_evidence'

module RCS
module SmsnewProcessing
  extend SingleEvidence

  def type
    :message
  end
end # ::Smsnew
end # ::RCS