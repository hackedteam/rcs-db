#
#  Manages the MongoDB shards
#

require 'mongoid'

module RCS
module DB

class Shard
  extend RCS::Tracer

  @db = Mongo::Connection.new("localhost").db("admin")

  def self.count
    list = @db.command({ listshards: 1 })
    list['shards'].size
  end

  def self.all
    @db.command({ listshards: 1 })
  end

  def self.create(host)
    trace :info, "Creating new shard: #{host}"
    begin
      @db.command({ addshard: host })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.destroy(host)
    trace :info, "Destroying shard: #{host}"
    begin
      @db.command({ removeshard: host })
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.find(id)
    begin
      self.all['shards'].each do |shard|
        if shard['_id'] == id
          host, port = shard['host'].split(':')
          db = Mongo::Connection.new(host, port.to_i).db("rcs")
          return db.stats
        end
      end
      {'errmsg' => 'Id not found', 'ok' => 0}
    rescue Exception => e
      {'errmsg' => e.message, 'ok' => 0}
    end
  end

  def self.enable(collection)
    begin
      @db.command({ enablesharding: collection })
    rescue Exception => e
      error = @db.command({ getlasterror: 1})
      error['err']
    end
  end
  
end

end #DB::
end #RCS::