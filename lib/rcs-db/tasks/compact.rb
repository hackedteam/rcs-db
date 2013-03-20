require_relative '../tasks'

module RCS
module DB

class CompactTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    collections = Mongoid::Config.master.collection_names.keep_if {|c| c['logs.'].nil? and c['system.'].nil?}
    collections.size * Shard.count
  end
  
  def next_entry
    yield @description = "Compacting DB"

    Shard.all['shards'].each do |shard|
      host, port = shard['host'].split(':')

      db = DB.instance.new_mongo_connection("rcs", host, port.to_i)

      db.collection_names.sort.keep_if {|c| c['logs.'].nil? and c['system.'].nil?  and c['_queue'].nil?}.each do |coll|
        yield @description = "Compacting #{coll}"
        db.command({compact: coll})
      end
    end

    @description = "DB compacted successfully"
  end
end

end # DB
end # RCS