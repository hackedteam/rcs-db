module RCS
  module Money
    module FindByHash
      def self.included(base)
        base.__send__(:extend, ClassMethods)
      end

      module ClassMethods
        def find(hash_or_id)
          if hash_or_id.kind_of?(Moped::BSON::ObjectId) or hash_or_id.to_s.size == 24
            super
          else
            where(hash: hash_or_id).first || raise("Cannot find #{self.name} #{hash_or_id.inspect}")
          end
        end
      end
    end
  end
end
