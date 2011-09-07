#
#  Manages the MongoDB shards
#

require 'mongoid'

module RCS
module DB

class Shard

  @db = Mongo::Connection.new("localhost").db("admin")

  def self.count
    list = @db.command({ listshards: 1 })
    list['shards'].size
  end

  def self.all
    @db.command({ listshards: 1 })
  end

  def self.create(host)
    @db.command({ addshard: host })
  end

  def self.destroy(host)
    @db.command({ removeshard: host })
  end

  def self.find(name)
    host, port = name.split(':')
    db = Mongo::Connection.new(host, port.to_i).db("rcs")
    db.stats
  end

  def self.enable(collection)
    @db.command({ enablesharding: collection })
  end
  
end

end #DB::
end #RCS::