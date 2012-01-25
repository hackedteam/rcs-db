module RCS
module FileopenProcessing
  def process
    puts "FILEOPEN: #{@info[:data]}"
  end

  def type
    :file
  end
end # ApplicationProcessing
end # DB
