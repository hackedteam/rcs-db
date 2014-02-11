module RCS
  module TargetScoped
    def self.included(base)
      base.__send__(:extend, ClassMethods)
    end

    def initialize(*args)
      self.class.check_collection_name
      super
    end

    module ClassMethods
      def check_collection_name
        raise "Missing target id. Maybe you're trying to access to #{name} without using the #target method." unless @target_id
      end

      def collection_name
        check_collection_name
        "#{collection_prefix}.#{@target_id}"
      end

      def collection_prefix
        @collection_prefix ||= name.to_s.downcase
      end

      def target(target)
        target_id = target.respond_to?(:id) ? target.id : target

        new_class_name = "#{collection_prefix.capitalize}#{target_id}"
        new_class_namespace = Object

        return new_class_namespace.const_get(new_class_name) if new_class_namespace.__send__(:const_defined?, new_class_name)

        new_class_namespace.const_set(new_class_name, self.dup)
        new_class = new_class_namespace.const_get(new_class_name)

        # Add a method to get the target_id
        new_class.define_singleton_method(:target_id) { @target_id ||= target_id }
        # Call it to create the instance variable @target_id on the singleton class
        new_class.target_id

        # Change storage options of the new class
        storage_options = (new_class.storage_options || {}).dup
        new_class.define_singleton_method(:storage_options) {
          storage_options.merge(store_in: {collection: collection_name})
        }

        new_class
      end
    end
  end
end
