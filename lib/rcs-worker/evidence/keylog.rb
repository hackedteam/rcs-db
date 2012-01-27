module RCS
module KeylogProcessing
  def process
    puts "KEYLOG: #{@info[:data]}"
  end

  def type
    :keylog
  end
end # ApplicationProcessing
end # DB
