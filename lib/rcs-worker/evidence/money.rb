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

    def fetch_input_addresses?
      data = self[:data]
      data[:type] == :tx && data[:from].nil? && data[:incoming] == 1
    end

    def fetch_input_addresses
      tx_hash = self[:data][:id]
      tx_currency = self[:data][:currency]
      tx_owner_addr = self[:data][:rcpt]

      db_name = "rcs_money_#{tx_currency}".strip.downcase
      tx = Mongoid.default_session.with(database: db_name)['tx'].find(h: tx_hash).limit(1).first

      # TODO: Support multiple input addresses (remove #first)
      tx['i'].first if tx and tx['o'].include?(tx_owner_addr)
    end

    def process
      self[:data][:from] = fetch_input_addresses if fetch_input_addresses?
      append_addresses_to_kw
    end

    def append_addresses_to_kw
      self[:kw] ||= []

      self[:kw] << self[:data][:from] if self[:data][:from]
      self[:kw] << self[:data][:rcpt] if self[:data][:rcpt]
    end
  end
end
