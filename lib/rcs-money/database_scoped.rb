module RCS
  module Money
    module DatabaseScoped
      DATABASE_NAME_PREFIX = 'rcs_money_'

      def self.included(base)
        base.__send__(:extend, ClassMethods)

        base.__send__(:before_save, :check_correct_database)
        base.__send__(:before_destroy, :check_correct_database)
      end

      def check_correct_database
        db = mongo_session.instance_variable_get('@current_database')
        correct = db && db.name.to_s.start_with?(DATABASE_NAME_PREFIX)
        raise("You cannot perform this action on database #{db.name}") unless correct
      end

      module ClassMethods
        def database_name_from_currency(currency)
          "#{DATABASE_NAME_PREFIX}#{currency}".strip.downcase
        end

        def for(currency)
          current_class_name = self.name.split('::').last
          new_class_name = "#{currency.to_s.capitalize}#{current_class_name}"
          new_class_namespace = RCS::Money

          return new_class_namespace.const_get(new_class_name) if new_class_namespace.__send__(:const_defined?, new_class_name)

          new_class_namespace.const_set(new_class_name, self.dup)
          new_class = new_class_namespace.const_get(new_class_name)

          # Change storage options of the new class
          storage_options = new_class.storage_options.dup
          new_class.define_singleton_method(:storage_options) {
            storage_options.merge(database: database_name_from_currency(currency))
          }

          # Add a method to get the name of the currency
          new_class.define_singleton_method(:currency) { currency }

          new_class
        end
      end
    end
  end
end
