require_relative 'single_evidence'

module RCS
module MouseProcessing
  extend SingleEvidence
  
  def process
    puts "MOUSE: #{self[:data]}"
  end

  def type
    :mouse
  end
end # ApplicationProcessing
end # DB
