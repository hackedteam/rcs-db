module RCS
  module Factory
    @@list = {}

    def self.create(name, params = {})
      factory = @@list[name] || raise("Unable to find factory #{name}")
      factory.run(params)
    end

    def self.define(name, &block)
      @@list[name] = RCS::Factory::Definition.new(name, &block)
    end

    module Helpers
      def factory_define(name, &block)
        Factory.define(name, &block)
      end

      def factory_create(name, params = {})
        Factory.create(name, params)
      end
    end

    class Definition
      include Helpers

      def initialize(name, &block)
        @name = name
        @block = block
      end

      def run(params)
        instance_exec(params, &@block)
      end
    end
  end
end


# Helpers (to be used in the spec files)

include RCS::Factory::Helpers


# Definitions

factory_define :operation do |params|
  attributes = {name: 'test-operation', _kind: 'operation', path: [], stat: ::Stat.new}
  attributes.merge! params
  Item.create! attributes
end

factory_define :target do |params|
  operation = params.delete(:operation) || factory_create(:operation)
  attributes = {name: "test-target", _kind: 'target', path: [operation._id], stat: ::Stat.new}
  attributes.merge! params
  Item.create! attributes
end

factory_define :target_entity do |params|
  target = params.delete(:target) || factory_create(:target)
  Entity.where(type: :target, path: target._id).first
end

factory_define :aggregate do |params|
  target = params.delete :target
  attributes = {day: Time.now.strftime('%Y%m%d'), aid: 'agent_id'}
  attributes.merge! params
  Aggregate.target(target).create! attributes
end

factory_define :agent do |params|
  target = params.delete(:target) || factory_create(:target)
  attributes = {name: 'test-agent', _kind: 'agent', path: target.path+[target.id], stat: ::Stat.new}
  attributes.merge! params
  Item.create! attributes
end