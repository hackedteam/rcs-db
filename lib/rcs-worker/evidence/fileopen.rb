require_relative 'single_evidence'

module RCS
module FileopenProcessing
  extend SingleEvidence
  
  def process
    puts "FILEOPEN: #{self[:data]}"
  end

  def type
    :file
  end
end # ApplicationProcessing
end # DB
