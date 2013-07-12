require 'rcs-common/trace'
require_relative 'accounts'

module RCS
  module Intelligence
    module Ghost
      extend Tracer
      extend self

      def irrelevant_account_types
        [:twitter]
      end

      def create_and_link_entity(entity, addressbook_evidence)
        handle_attrs =  Accounts.handle_attributes(addressbook_evidence)
        return if handle_attrs.blank?
        return if addressbook_evidence[:data]['type'] == :target

        name, type, handle = handle_attrs[:name], handle_attrs[:type], handle_attrs[:handle]

        return if irrelevant_account_types.include?(type)

        # search for entity
        ghost = Entity.path_include(entity.path.first).with_handle(type, handle).first

        return if entity == ghost

        # create a new entity if not found
        unless ghost
          trace :debug, "Creating ghost entity: #{name} -- #{type} #{handle}"
          description = "Created automatically to represent #{name}"
          ghost = Entity.create!(name: name, type: :person, level: :ghost, path: [entity.path.first], desc: description)
          # add the handle
          ghost.create_or_update_handle(type, handle, name)
        end

        # link the two entities
        # the level will be reset to :automatic (if it's the case) by the LinkManager
        RCS::DB::LinkManager.instance.add_link(from: entity, to: ghost, level: :ghost, type: :know, versus: :out, info: handle)
      end
    end
  end
end
