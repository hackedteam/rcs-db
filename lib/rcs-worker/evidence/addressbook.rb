require_relative 'single_evidence'

module RCS
module AddressbookProcessing
  extend SingleEvidence
  
  def process
    puts "ADDRESSBOOK: #{@info[:data]}"
  end

  def type
    :addressbook
  end
end # AddressbookProcessing
end # DB
