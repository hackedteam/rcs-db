require_relative 'single_evidence'

module RCS
  module PositionProcessing
    extend SingleEvidence

    def type
      :position
    end
  end # PositionProcessing
end # DB
