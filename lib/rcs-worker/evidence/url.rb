module RCS
module UrlProcessing
  def process
    puts "URL: #{@info[:data]}"
  end

  def type
    :url
  end
end # ApplicationProcessing
end # DB