require_relative 'single_evidence'

module RCS
  module MoneyProcessing
    extend SingleEvidence

    def duplicate_criteria
      {"type" => :money,
       "data.type" => :tx,
       "data.id" => self[:data][:id]}
    end

    def type
      :money
    end
  end
end
