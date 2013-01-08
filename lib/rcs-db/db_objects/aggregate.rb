require 'mongoid'

#module RCS
#module DB

class Aggregate
  extend RCS::Tracer

  def self.collection_name(target)
    "aggregate.#{target}"
  end

  def self.collection_class(target)

    classDefinition = <<-END
      class Aggregate_#{target}
        include Mongoid::Document

        field :day, type: String                      # day of aggregation
        field :type, type: String
        field :count, type: Integer, default: 0
        field :size, type: Integer, default: 0        # seconds for calls, bytes for the rest
        field :data, type: Hash

        store_in Aggregate.collection_name('#{target}')

        index :type, background: true
        index :day, background: true
        index "data.peer", background: true
        shard_key :type, :day

        after_create :create_callback

        protected

        def create_callback
          # enable sharding only if not enabled
          db = Mongoid.database
          coll = db.collection(Aggregate.collection_name('#{target}'))
          unless coll.stats['sharded']
            Aggregate.collection_class('#{target}').create_indexes
            RCS::DB::Shard.set_key(coll, {type: 1, day: 1})
          end
        end

      end
    END
    
    classname = "Aggregate_#{target}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval classDefinition
      klass = eval classname
    end
    
    return klass
  end

  def self.dynamic_new(target_id)
    klass = self.collection_class(target_id)
    return klass.new
  end


end

#end # ::DB
#end # ::RCS