require_relative 'single_evidence'

module RCS
module ClipboardProcessing
  extend SingleEvidence
  
  def process
    puts "CLIPBOARD: #{@info[:data]}"
  end

  def type
    :clipboard
  end
end # DeviceProcessing
end # RCS
