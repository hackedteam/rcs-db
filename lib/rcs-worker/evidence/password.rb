module RCS
module PasswordProcessing
  def process
    puts "PASSWORD: #{@info[:data]}"
  end

  def type
    :password
  end
end # ApplicationProcessing
end # DB
