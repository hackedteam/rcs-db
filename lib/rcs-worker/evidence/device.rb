require_relative 'single_evidence'

module RCS
module DeviceProcessing
  extend SingleEvidence
  
  def process
    puts "DEVICE: #{self[:data]}"
  end
  
  def type
    :device
  end
end # DeviceProcessing
end # RCS
