require_relative 'single_evidence'

module RCS
  module MmsProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::MmsProcessing
end # ::RCS