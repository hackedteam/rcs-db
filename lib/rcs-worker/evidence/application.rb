require_relative 'single_evidence'

module RCS
module ApplicationProcessing
  extend SingleEvidence
  
  def process
    puts "APPLICATION: #{self[:data]}"
  end

  def type
    :application
  end
end # ApplicationProcessing
end # DB
