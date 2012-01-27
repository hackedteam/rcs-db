module RCS
module DeviceProcessing
  def process
    puts "DEVICE: #{@info[:data]}"
  end

  def type
    :device
  end
end # DeviceProcessing
end # RCS
