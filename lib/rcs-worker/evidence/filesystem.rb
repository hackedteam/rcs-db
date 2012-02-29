require_relative 'single_evidence'

module RCS
module FilesystemProcessing
  extend SingleEvidence
  
  def process
    puts "FILESYSTEM: #{self[:data]}"
  end

  def type
    :filesystem
  end
end # FilesystemProcessing
end # DB
