require_relative 'single_evidence'

module RCS
module AddressbookProcessing
  extend SingleEvidence

  def duplicate_criteria
    {"type" => :addressbook,
     "data.name" => self[:data][:name],
     "data.contact" => self[:data][:contact],
     "data.info" => self[:data][:info]}
  end

  def type
    :addressbook
  end
end # AddressbookProcessing
end # DB
