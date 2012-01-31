require_relative 'single_evidence'

module RCS
module SnapshotProcessing
  extend SingleEvidence
  
  def process
    puts "SNAPSHOT: #{@info[:data]}"
  end

  def type
    :screenshot
  end
end # ApplicationProcessing
end # DB
