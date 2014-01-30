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

    def money_module_loaded?
      @@money_module_loaded ||= RCS.__send__(:const_defined?, :'Money') and RCS::Money.__send__(:const_defined?, :'Tx')
    end

    def tx?
      self[:data][:type] == :tx
    end

    def missing_from_addr?
      self[:data][:incoming] == 1 and !self[:data][:from]
    end

    def process
      if money_module_loaded? and tx? and missing_from_addr?
        currency = self[:data][:currency]
        tx_hash = self[:data][:id]

        tx = RCS::Money::Tx.for(currency).find(tx_hash) rescue nil

        return unless tx

        from_addresses = tx.in.uniq

        return if from_addresses.empty?

        self[:data][:from] = from_addresses.size == 1 ? from_addresses.first : from_addresses
      end
    end
  end
end
