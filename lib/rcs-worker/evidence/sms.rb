require_relative 'single_evidence'

module RCS
  module SmsProcessing
    extend SingleEvidence

    def type
      :message
    end
  end # ::SmsProcessing
end # ::RCS