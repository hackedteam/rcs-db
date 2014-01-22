require 'rcs-common/trace'
require 'rcs-common/evidence/money'

module RCS
module Intelligence

module Accounts
  extend Tracer
  extend self

  def known_cryptocurrencies
    RCS::MoneyEvidence::TYPES.keys
  end

  def known_services
    [:facebook, :twitter, :gmail, :skype, :bbm, :whatsapp,
     :phone, :mail, :linkedin, :viber, :outlook, :wechat, :line].concat(known_cryptocurrencies)
  end

  def service_to_handle_type service
    if [:mail, :gmail, :outlook].include? service
      :mail
    else
      service
    end
  end

  # Check if the given evidence has all the information that
  # the #add_handle method needs.
  def valid_addressbook_evidence?(evidence)
    return false unless evidence.type == 'addressbook'
    data = evidence[:data]
    return false unless known_services.include? data['program']
    return false if data['handle'].blank?
    true
  end

  # If the given evidence is valid, an it represents an local (of the entity)
  # account, add an EntityHandle to the given Entity.
  def add_handle(entity, addressbook_evidence)
    data = addressbook_evidence[:data]
    return unless data['type'] == :target

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
    handle_type = service_to_handle_type data['program']
    handle = data['handle']
    handle.downcase! unless known_cryptocurrencies.include?(handle_type)

    name = data['name'].blank? ? handle : data['name']

    {name: name, type: handle_type, handle: handle}
  end

  def update_person_entity_name entity, addressbook_evidence
    attrs = handle_attributes addressbook_evidence
    return unless attrs
    return if attrs[:handle] == attrs[:name]

    operation = entity.path.first

    entity = Entity.persons.path_include(operation)
             .with_handle(attrs[:type], attrs[:handle])
             .where('name'=> attrs[:handle])
             .first

    entity.update_attributes!(name: attrs[:name]) if entity
  end
end

end
end
