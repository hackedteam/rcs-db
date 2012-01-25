module RCS
module ChatProcessing
  def process
    puts "CHAT: #{@info[:data]}"
  end

  def type
    :chat
  end
end # DeviceProcessing
end # RCS
