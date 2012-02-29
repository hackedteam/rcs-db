require 'mail'
require_relative 'single_evidence'

module RCS
module MailrawProcessing
  extend SingleEvidence
  
  def process
    mail = Mail.read_from_string(self[:grid_content])

    self[:data][:from] = mail.from.collect {|address| address.to_s.force_encoding('UTF-8') }
    self[:data][:rcpt] = mail.to.to_s
    self[:data][:rcpt] ||= []
    self[:data][:sent_date] = mail.date.to_s.force_encoding('UTF-8')
    self[:data][:subject] = mail.subject.to_s.force_encoding('UTF-8')
    self[:data][:body] = mail.body.decoded.force_encoding('UTF-8')

=begin
    puts @info[:data][:from][0]
    puts @info[:data][:rcpt][0]
    puts @info[:data][:sent_date]
    puts @info[:data][:subject]
    puts @info[:data][:body]
=end

    self[:data][:type] = 'mail'.force_encoding('UTF-8')
  end
  
  def type
    :message
  end
end # ::Mailraw
end # ::RCS
