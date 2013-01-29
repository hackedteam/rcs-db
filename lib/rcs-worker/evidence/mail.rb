require_relative 'single_evidence'

module RCS
module MailProcessing
  extend SingleEvidence

  def type
    :message
  end
end # ::Mail
end # ::RCS
