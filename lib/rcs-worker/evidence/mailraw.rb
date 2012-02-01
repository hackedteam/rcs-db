require 'mail'
require_relative 'single_evidence'

module RCS
module MailrawProcessing
  extend SingleEvidence
  
  def process
    mail = Mail.read_from_string(@info[:grid_content])
    
    @info[:data][:from] = mail.from
    @info[:data][:to] = mail.to
    @info[:data][:to] ||= ''
    @info[:data][:sent_date] = mail.date.to_s
    @info[:data][:subject] = mail.subject.to_s
    @info[:data][:body] = mail.body.decoded
  end
  
  def type
    :mail
  end
end # ::Mailraw
end # ::RCS
