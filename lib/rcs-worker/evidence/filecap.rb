require_relative 'single_evidence'

module RCS
module FilecapProcessing
  extend SingleEvidence
  
  def process
    puts "FILECAP: #{self[:data]}"
  end

  def type
    :file
  end
end # ApplicationProcessing
end # DB
