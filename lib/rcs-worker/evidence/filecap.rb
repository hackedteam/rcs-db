module RCS
module FilecapProcessing
  def process
    puts "FILECAP: #{@info[:data]}"
  end

  def type
    :file
  end
end # ApplicationProcessing
end # DB
