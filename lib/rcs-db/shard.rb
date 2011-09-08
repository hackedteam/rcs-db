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
    @db.command({ addshard: host })
  end

  def self.destroy(host)
    trace :info, "Destroying shard: #{host}"
    @db.command({ removeshard: host })
  end

  def self.find(name)
    host, port = name.split(':')
    begin
      db = Mongo::Connection.new(host, port.to_i).db("rcs")
      db.stats
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