require 'mail'
require_relative 'single_evidence'

module RCS
module MailrawProcessing
  extend SingleEvidence
  
  def process
    mail = Mail.read_from_string(@info[:content])
    @info[:from] = mail.from.join(', ')
    @info[:to] = mail.to.join(', ')
    @info[:to] ||= ''
    @info[:sent_date] = mail.date.to_s
    @info[:subject] = mail.subject.to_s
    @info[:body] = mail.body.decoded
    
    #puts "From:    #{@info[:from]}"
    #puts "To:      #{@info[:to]}"
    #puts "Sent:    #{@info[:sent_date]}"
    #puts "Subject: #{@info[:subject]}"
  end

  def type
    :mail
  end
end # ::Mailraw
end # ::RCS