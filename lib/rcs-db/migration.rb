#
# Helper for migration between versions
#

require 'mongoid'
require 'set'

require 'rcs-common/trace'

require_relative 'db_objects/group'
require_relative 'config'
require_relative 'db_layer'

module RCS
module DB

class Migration

  def self.run(params)
    puts "Migration procedure started..."

    # we are standalone (no rails or rack)
    ENV['MONGOID_ENV'] = 'yes'

    # set the parameters for the mongoid.yaml
    ENV['MONGOID_DATABASE'] = 'rcs'
    ENV['MONGOID_HOST'] = "127.0.0.1:27017"

    Mongoid.load!(RCS::DB::Config.instance.file('mongoid.yaml'), :production)

    puts "Connected to MongoDB at #{ENV['MONGOID_HOST']}"

    params.each do |step|
      puts "\n+ #{step}"
      self.send(step)
    end

    return 0
  end

  def self.mongoid3
    start = Time.now
    count = 0
    puts "Recalculating item checksums..."
    ::Item.each do |item|
      count += 1
      item.cs = item.calculate_checksum
      item.save
      print "\r%d items migrated" % count
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

  def self.access_control
    start = Time.now
    count = 0
    puts "Rebuilding access control..."
    ::Item.operations.each do |operation|
      count += 1
      Group.rebuild_access_control(operation)
      print "\r%d operations rebuilt" % count
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

  def self.reindex_aggregates
    start = Time.now
    count = 0
    db = DB.instance.mongo_connection
    puts "Re-indexing aggregates..."
    ::Item.targets.each do |target|
      begin
        Aggregate.collection_class(target._id).collection.indexes.drop
        Aggregate.collection_class(target._id).create_indexes
        coll = db.collection('aggregate.' + target._id.to_s)
        Shard.set_key(coll, {type: 1, day: 1, aid: 1})
        print "\r%d aggregates reindexed" % count += 1
      rescue
      end
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

end

end
end
