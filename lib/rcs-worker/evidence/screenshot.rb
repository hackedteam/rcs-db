require_relative 'single_evidence'
require_relative 'thumbnailable'

module RCS
module ScreenshotProcessing
  extend SingleEvidence
  include Thumbnailable

  def type
    :screenshot
  end
end # ApplicationProcessing
end # DB
