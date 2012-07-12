require_relative 'single_evidence'

module RCS
module DeviceProcessing
  extend SingleEvidence

  def type
    :device
  end

  def process
    puts self[:data]
    puts self[:data][:content].keywords
  end

end # DeviceProcessing
end # RCS
