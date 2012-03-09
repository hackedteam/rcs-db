require_relative 'single_evidence'

module RCS
module CameraProcessing
  extend SingleEvidence

  def type
    :camera
  end
end # ApplicationProcessing
end # DB
