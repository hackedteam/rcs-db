module RCS
module ClipboardProcessing
  def process
    puts "CLIPBOARD: #{@info[:data]}"
  end

  def type
    :clipboard
  end
end # DeviceProcessing
end # RCS
