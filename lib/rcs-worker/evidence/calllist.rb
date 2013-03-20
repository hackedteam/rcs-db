require_relative 'single_evidence'

module RCS
  module CalllistProcessing
    extend SingleEvidence

    def type
      :call
    end
  end # CalllistProcessing

  module CalllistoldProcessing
    extend SingleEvidence

    def type
      :call
    end
  end # CalllistProcessing
end # DB
