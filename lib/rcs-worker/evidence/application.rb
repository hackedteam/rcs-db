module RCS
module ApplicationProcessing
  def process
    puts "APPLICATION: #{@info[:data]}"
  end

  def type
    :application
  end
end # ApplicationProcessing
end # DB
