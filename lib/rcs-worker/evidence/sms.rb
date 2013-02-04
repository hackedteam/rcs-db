require_relative 'single_evidence'

module RCS
  module SmsProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::SmsProcessing

  module SmsoldProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::SmsoldProcessing

end # ::RCS