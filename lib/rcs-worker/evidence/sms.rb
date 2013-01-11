require_relative 'single_evidence'

module RCS
  module SmsProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::SmsProcessing

  module SmsnewProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::SmsnewProcessing

end # ::RCS