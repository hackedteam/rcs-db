require_relative '../tasks'

module RCS
module DB

class CompactTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    collections = DB.instance.collection_names.keep_if {|c| c['logs.'].nil? and c['system.'].nil?}
    collections.size * Shard.count
  end
  
  def next_entry
    yield @description = "Compacting DB"

    Shard.all['shards'].each do |shard|
      host, port = shard['host'].split(':')

      trace :info, "Compacting #{host} #{port}"

      DB.instance.open(host, port, 'rcs') do |db|
        db.collections.map(&:name).sort.keep_if {|c| c['logs.'].nil? and c['system.'].nil? and c['_queue'].nil?}.each do |coll|
          yield @description = "Compacting #{coll}"
          db.command(compact: coll)
        end
      end
    end

    @description = "DB compacted successfully"
  end
end

end # DB
end # RCS