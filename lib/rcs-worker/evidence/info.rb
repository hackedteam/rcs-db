require_relative 'single_evidence'

module RCS
module InfoProcessing
  extend SingleEvidence
  
  def process
    puts "INFO: #{self[:data]}"
  end

  def type
    :info
  end
end # ApplicationProcessing
end # DB
