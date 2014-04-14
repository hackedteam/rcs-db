#
#  Manages the MongoDB shards
#

require 'mongoid'

module RCS
module DB

class Shard
  extend RCS::Tracer

  def self.count
    db = DB.instance.session("admin")
    list = db.command({ listshards: 1 })
    list['shards'].size
  end

  def self.all
    db = DB.instance.session("admin")
    db.command({ listshards: 1 })
  end

  def self.hosts
    sorted.map { |info| info['host'] }
  end

  def self.sorted
    shards = all['shards']
    shards.sort_by { |x| x['_id'] }
  end

  def self.last
    sorted.last['_id']
  end

  def self.first
    sorted.first['_id']
  end

  def self.create(host)
    trace :info, "Creating new shard: #{host}"
    begin
      db = DB.instance.session("admin")
      db.command({ addshard: host + ':27018' })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.destroy(host)
    trace :info, "Destroying shard: #{host}"
    begin
      db = DB.instance.session("admin")
      db.command({ removeshard: host })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.remove(shard)
    DB.instance.open("127.0.0.1", 27019, 'config') do |db|
      db['shards'].remove(_id: shard)
    end
    {'ok' => 1}
  rescue Exception => e
    {'errmsg' => e.message, 'ok' => 0}
  end

  def self.add(shard, host)
    DB.instance.open("127.0.0.1", 27019, 'config') do |db|
      return db['shards'].insert({_id: shard, host: host + ':27018'})
    end
  rescue Exception => e
    {'errmsg' => e.message, 'ok' => 0}
  end

  def self.update(shard, host)
    DB.instance.open("127.0.0.1", 27019, 'config') do |db|
      db['shards'].find({_id: shard}).update({'$set' => {'host' => host + ':27018'}})
    end
    {'ok' => 1}
  rescue Exception => e
    {'errmsg' => e.message, 'ok' => 0}
  end

  def self.find(id)
    begin
      self.all['shards'].each do |shard|
        if shard['_id'] == id
          host, port = shard['host'].split(':')
          stats = nil
          DB.instance.open(host, port, 'rcs', raise: false) { |db| stats = db.command(dbStats: 1) }
          return {'errmsg' => "Cannot establish connection to #{host}:#{port}"} if stats.nil?
          return stats
        end
      end
      {'errmsg' => 'Id not found', 'ok' => 0}
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.enable(database)
    db = DB.instance.session("admin")
    return db.command({ enablesharding: database })
  rescue Moped::Errors::OperationFailure => ex
    ex.details['errmsg']
  rescue Exception => e
    error = db.command({ getlasterror: 1})
    error['err']
  end

  def self.sharded?(collection)
    DB.instance.sharded_collection?(collection)
  end

  def self.set_key(collection, key)
    # we need an index before the creation of the shard
    collection.indexes.create(key)

    # switch to 'admin' and create the shard
    db = DB.instance.session("admin")
    namespace = DB.instance.collection_stats(collection.name)['ns']
    db.command(shardcollection: namespace, key: key)

  rescue Exception => e
    # sometimes the collection is already sharded and we don't want to report an error
    #trace :error, "Cannot enable shard key: #{e.message} " #+ db.command({ getlasterror: 1})
    trace(:error, "shard#add_key #{collection} #{key}: #{e.class} #{e.message}")
    e.message
  end
  
end

end #DB::
end #RCS::