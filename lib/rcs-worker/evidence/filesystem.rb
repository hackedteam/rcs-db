require_relative 'single_evidence'

module RCS
module FilesystemProcessing
  extend SingleEvidence

  def type
    :filesystem
  end
end # FilesystemProcessing
end # DB
