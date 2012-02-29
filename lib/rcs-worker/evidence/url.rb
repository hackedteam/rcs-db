require_relative 'single_evidence'

module RCS
module UrlProcessing
  extend SingleEvidence

  def process
    puts "URL: #{self[:data]}"
  end

  def type
    :url
  end
end # ApplicationProcessing
end # DB