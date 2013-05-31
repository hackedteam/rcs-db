require 'rcs-common/trace'

module RCS
module Intelligence

module Accounts
  extend Tracer
  extend self

  def known_services
    [:facebook, :twitter, :gmail, :skype, :bbm, :whatsapp, :phone, :mail, :linkedin, :viber, :outlook]
  end

  # Check if the given evidence if the given addressbook evidence
  # has all the information that #add_handle method needs.
  def valid_addressbook_evidence?(evidence)
    return false unless evidence.type == 'addressbook'
    data = evidence[:data]
    return false unless data['type'] == :target
    return false unless known_services.include? data['program']
    return false if data['handle'].blank?
    true
  end

  # If the given evidence is valid, add an EntityHandle to the
  # given Entity.
  def add_handle(entity, addressbook_evidence)
    data = addressbook_evidence[:data]

    trace :debug, "Parsing handle data: #{data.inspect}"

    attrs = handle_attributes addressbook_evidence
    return if attrs.blank?

    entity.create_or_update_handle attrs[:type], attrs[:handle], attrs[:name]
  rescue Exception => e
    trace :error, "Cannot add handle: #{e.message}"
    trace :fatal, e.backtrace.join("\n")
  end

  # Extracts some information from the given evidence
  # @return Nil or an hash with the attributes for a valid EntityHandle.
  def handle_attributes(addressbook_evidence)
    return unless valid_addressbook_evidence? addressbook_evidence

    data = addressbook_evidence[:data]

    # TODO: convert data['program'] to the right format, for example
    # :gmail => :mail
    {name: data['name'], type: data['program'], handle: data['handle'].downcase}
  end
end

end
end
