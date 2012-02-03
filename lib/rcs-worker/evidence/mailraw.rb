require 'mail'
require_relative 'single_evidence'

module RCS
module MailrawProcessing
  extend SingleEvidence
  
  def process
    mail = Mail.read_from_string(@info[:grid_content])
    
    @info[:data][:from] = mail.from
    @info[:data][:rcpt] = mail.to
    @info[:data][:rcpt] ||= ''
    @info[:data][:sent_date] = mail.date.to_s
    @info[:data][:subject] = mail.subject.to_s
    @info[:data][:body] = mail.body.decoded
    
    @info[:data][:type] = 'mail'
  end
  
  def type
    :message
  end
end # ::Mailraw
end # ::RCS
