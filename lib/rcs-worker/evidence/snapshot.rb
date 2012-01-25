module RCS
module SnapshotProcessing
  def process
    puts "SNAPSHOT: #{@info[:data]}"
  end

  def type
    :screenshot
  end
end # ApplicationProcessing
end # DB
