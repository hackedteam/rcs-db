require_relative 'single_evidence'

module RCS
module ClipboardProcessing
  extend SingleEvidence

  def type
    :clipboard
  end
end # DeviceProcessing
end # RCS
