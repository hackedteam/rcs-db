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

      db = Mongo::Connection.new(host, port.to_i).db("rcs")
      db.authenticate(DB::AUTH_USER, DB::AUTH_PASS)

      db.collection_names.sort.keep_if {|c| c['logs.'].nil? and c['system.'].nil?}.each do |coll|
        yield @description = "Compacting #{coll}"
        db.command({compact: coll})
      end
    end

    @description = "DB compacted successfully"
  end
end

end # DB
end # RCS