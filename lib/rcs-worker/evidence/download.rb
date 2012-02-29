require_relative 'single_evidence'

module RCS
  module DownloadProcessing
    extend SingleEvidence

    def process
      puts "DOWNLOAD: #{self[:data]}"
    end

    def type
      :file
    end
  end # DownloadProcessing
end # RCS
