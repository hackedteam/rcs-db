module RCS
module DeviceProcessing
  def process
    puts "DEVICE: #{@info[:data]}"
  end

  def device
    :device
  end
end # DeviceProcessing
end # RCS
