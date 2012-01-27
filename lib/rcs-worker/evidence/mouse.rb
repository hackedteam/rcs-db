module RCS
module MouseProcessing
  def process
    puts "MOUSE: #{@info[:data]}"
  end

  def type
    :mouse
  end
end # ApplicationProcessing
end # DB
