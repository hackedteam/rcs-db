module RCS
module InfoProcessing
  def process
    puts "INFO: #{@info[:data]}"
  end

  def type
    :info
  end
end # ApplicationProcessing
end # DB
