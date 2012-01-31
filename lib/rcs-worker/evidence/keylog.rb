require_relative 'single_evidence'

module RCS
module KeylogProcessing
  extend SingleEvidence
  
  def process
    puts "KEYLOG: #{@info[:data]}"
  end

  def type
    :keylog
  end
end # ApplicationProcessing
end # DB
