require_relative 'single_evidence'

module RCS
module PasswordProcessing
  extend SingleEvidence
  
  def process
    puts "PASSWORD: #{@info[:data]}"
  end

  def type
    :password
  end
end # ApplicationProcessing
end # DB
