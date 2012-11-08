require_relative 'single_evidence'

module RCS
  module ExecProcessing
    extend SingleEvidence

    def type
      :command
    end
  end # CommandProcessing
end # RCS
