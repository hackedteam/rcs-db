require 'mail'
require_relative 'single_evidence'

module RCS
module MailrawProcessing
  extend SingleEvidence

  def type
    :message
  end
end # ::Mailraw
end # ::RCS
