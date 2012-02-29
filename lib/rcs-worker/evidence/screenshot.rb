require_relative 'single_evidence'

module RCS
module ScreenshotProcessing
  extend SingleEvidence
  
  def process
    puts "SCREENSHOT: #{self[:data]}"
  end

  def type
    :screenshot
  end
end # ApplicationProcessing
end # DB
