module RCS
module PrintProcessing
  def process
    puts "PRINT: #{@info[:data]}"
  end

  def type
    :print
  end
end # ApplicationProcessing
end # DB
