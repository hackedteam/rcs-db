#
#  Manages the MongoDB shards
#

require 'mongoid'

module RCS
module DB

class Shard
  extend RCS::Tracer

  def self.count
    db = DB.instance.mongo_connection("admin")
    list = db.command({ listshards: 1 })
    list['shards'].size
  end

  def self.all
    db = DB.instance.mongo_connection("admin")
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
      db = DB.instance.mongo_connection("admin")
      db.command({ addshard: host + ':27018' })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.destroy(host)
    trace :info, "Destroying shard: #{host}"
    begin
      db = DB.instance.mongo_connection("admin")
      db.command({ removeshard: host })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end
  
  def self.remove(shard)
    begin
      conn = DB.instance.new_mongo_connection("127.0.0.1", 27019)
      coll = conn.db('config').collection('shards')
      coll.remove({_id: shard})
      conn.close
      return {'ok' => 1}
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.add(shard, host)
    begin
      conn = DB.instance.new_mongo_connection("127.0.0.1", 27019)
      coll = conn.db('config').collection('shards')
      ret = coll.insert({_id: shard, host: host + ':27018'})
      conn.close
      return ret
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.update(shard, host)
    begin
      conn = DB.instance.new_mongo_connection("127.0.0.1", 27019)
      coll = conn.db('config').collection('shards')
      coll.update({_id: shard}, {'$set' => {'host' => host + ':27018'}})
      conn.close
      return {'ok' => 1}
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.find(id)
    begin
      self.all['shards'].each do |shard|
        if shard['_id'] == id
          host, port = shard['host'].split(':')
          db = DB.instance.new_mongo_connection(host, port.to_i).db('rcs')
          return {'errmsg' => "Cannot establish connection to #{host}:#{port}"} if db.nil?
          return db.stats
        end
      end
      {'errmsg' => 'Id not found', 'ok' => 0}
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.enable(database)
    begin
      db = DB.instance.mongo_connection("admin")
      db.command({ enablesharding: database })
    rescue Exception => e
      error = db.command({ getlasterror: 1})
      error['err']
    end
  end

  def self.set_key(collection, key)
    #trace :info, "Enabling shard key #{key.inspect} on #{collection.stats['ns']}"
    begin
      # we need an index before the creation of the shard
      collection.create_index(key.to_a)

      # switch to 'admin' and create the shard
      db = DB.instance.mongo_connection("admin")
      db.command({ shardcollection: collection.stats['ns'], key: key })

    rescue Exception => e
      # sometimes the collection is already sharded and we don't want to report an error
      #trace :error, "Cannot enable shard key: #{e.message} " #+ db.command({ getlasterror: 1})
      e.message
    end
  end
  
end

end #DB::
end #RCS::