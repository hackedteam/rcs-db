require_relative 'single_evidence'

module RCS
module AddressbookProcessing
  extend SingleEvidence

  def type
    :addressbook
  end
end # AddressbookProcessing
end # DB
