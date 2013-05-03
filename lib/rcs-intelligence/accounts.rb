#
#  Module for retrieving the accounts of the targets
#

require 'mail'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module Intelligence

class Accounts
  include Tracer
  extend Tracer

  class << self

    def addressbook_types
      [:facebook, :twitter, :gmail, :skype, :bbm, :whatsapp, :phone, :mail, :linkedin, :viber]
    end

    def password_types
      {
        gmail:    {domain: '@gmail.com', regexp: /gmail|google/i},
        facebook: {domain: '@facebook.com', regexp: /facebook/i}
      }
    end

    def add_handle(entity, evidence)
      data = evidence[:data]

      trace :debug, "Parsing handle data: #{data.inspect}"

      # target account in the contacts (addressbook)
      if addressbook_types.include? data['program']
        return if data['type'] != :target

        if data['handle']
          create_entity_handle(entity, data['program'], data['handle'].downcase, data['name'])
        end
      elsif (data['program'] =~ /outlook|mail/i || data['user'])
        # mail accounts from email clients saving account to the device
        # OR infer on the user to discover email addresses (for passwords)
        create_entity_handle_from_user entity, data['user'], data['service']
      end
    rescue Exception => e
      trace :error, "Cannot add handle: " + e.message
      trace :fatal, e.backtrace.join("\n")
    end

    def create_entity_handle_from_user entity, user, service
      handle = user.downcase
      add_domain handle, service
      type = get_type handle, service
      return if !is_mail? handle
      create_entity_handle entity, type, handle, ''
    end

    def create_entity_handle entity, type, handle, name
      entity.create_or_update_handle type, handle, name
    end

    def is_mail?(value)
      return false if value == ''
      parsed = Mail::Address.new(value)
      return parsed.address == value && parsed.local != parsed.address
    rescue Mail::Field::ParseError
      return false
    end

    def add_domain user, service
      return if is_mail? user
      password_types.each do |type, opts|
        user << opts[:domain] if service =~ opts[:regexp]
      end
      # TODO: add also non-standard domain (like hotmail or yahoo)
      user
    end

    def get_type user, service
      #if already in email form, check the domain, else check the service
      to_search = is_mail?(user) ? user : service
      password_types.each do |type, opts|
        return type if to_search =~ opts[:regexp]
      end
      return :mail
    end

    def get_addressbook_handle(evidence)
      data = evidence[:data]

      if addressbook_types.include? data['program']
        # don't return data from the target
        return nil if data['type'].eql? :target
        return [data['name'], data['program'], data['handle'].downcase] if data['handle']
      end
      return nil
    end

  end

end

end
end

