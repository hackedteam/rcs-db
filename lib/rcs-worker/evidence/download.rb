require_relative 'single_evidence'

module RCS
  module DownloadProcessing
    extend SingleEvidence

    def type
      :file
    end
  end # DownloadProcessing
end # RCS
