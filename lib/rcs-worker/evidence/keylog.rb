module RCS
module KeylogProcessing
  def process
    puts "KEYLOG: #{@info[:data]}"
  end

  def keylog
    :keylog
  end
end # ApplicationProcessing
end # DB
