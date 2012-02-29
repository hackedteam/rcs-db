require_relative 'single_evidence'

module RCS
module AddressbookProcessing
  extend SingleEvidence
  
  def process
    puts "ADDRESSBOOK: #{self[:data]}"
  end

  def type
    :addressbook
  end
end # AddressbookProcessing
end # DB
