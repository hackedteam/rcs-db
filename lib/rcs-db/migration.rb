#
# Helper for migration between versions
#

require 'mongoid'
require 'set'

require 'rcs-common/trace'

require_relative 'db_objects/group'
require_relative 'db_objects/session'
require_relative 'config'
require_relative 'db_layer'

module RCS
module DB

module Migration
  extend self

  def up_to(version)
    puts "migrating to #{version}"

    run [:recalculate_checksums, :drop_sessions]

    return 0
  end

  def run(params)
    puts "\nMigration procedure started..."

    ENV['no_trace'] = '1'

    #Mongoid.logger = ::Logger.new($stdout)
    #Moped.logger = ::Logger.new($stdout)

    #Mongoid.logger.level = ::Logger::DEBUG
    #Moped.logger.level = ::Logger::DEBUG

    # we are standalone (no rails or rack)
    ENV['MONGOID_ENV'] = 'yes'

    # set the parameters for the mongoid.yaml
    ENV['MONGOID_DATABASE'] = 'rcs'
    ENV['MONGOID_HOST'] = "127.0.0.1"
    ENV['MONGOID_PORT'] = "27017"

    Mongoid.load!(RCS::DB::Config.instance.file('mongoid.yaml'), :production)

    puts "Connected to MongoDB at #{ENV['MONGOID_HOST']}:#{ENV['MONGOID_PORT']}"

    params.each do |step|
      start = Time.now
      puts "Running #{step}"
      __send__(step)
      puts "\n#{step} completed in #{Time.now - start} sec"
    end

    return 0
  end

  def recalculate_checksums
    count = 0
    ::Item.each do |item|
      count += 1
      item.cs = item.calculate_checksum
      item.save
      print "\r%d items migrated" % count
    end
  end

  def mark_pre_83_as_bad
    count = 0
    ::Item.agents.each do |item|
      count += 1
      item.good = false if item.version < 2013031101
      item.save
      print "\r%d items checked" % count
    end
  end

  def access_control
    count = 0
    ::Item.operations.each do |operation|
      count += 1
      Group.rebuild_access_control(operation)
      print "\r%d operations rebuilt" % count
    end
  end

  def reindex_aggregates
    count = 0
    ::Item.targets.each do |target|
      begin
        klass = Aggregate.target(target._id)
        DB.instance.sync_indexes(klass)
        print "\r%d aggregates collection reindexed" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
  end

  def reindex_evidences
    count = 0
    ::Item.targets.each do |target|
      begin
        klass = Evidence.target(target._id)
        DB.instance.sync_indexes(klass)
        print "\r%d evidences collection reindexed" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
  end

  def aggregate_summary
    count = 0
    ::Item.targets.each do |target|
      begin
        next if Aggregate.target(target._id).empty?

        Aggregate.target(target._id).rebuild_summary
        print "\r%d summaries" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
  end

  def drop_sessions
    ::Session.destroy_all
  end

  def cleanup_storage
    count = 0
    db = DB.instance.mongo_connection

    total_size =  db.stats['dataSize']

    collections = db.collection_names
    # keep only collection with _id in the name
    collections.keep_if {|x| x.match /\.[a-f0-9]{24}/}
    puts "#{collections.size} collections"
    targets = Item.targets.collect {|t| t.id.to_s}
    puts "#{targets.size} targets"
    # remove collections of existing targets
    collections.delete_if {|x| targets.any? {|t| x.match /#{t}/}}
    collections.each {|c| db.drop_collection c }
    puts "#{collections.size} collections deleted"
    puts "done in #{Time.now - start} secs"
    puts

    start = Time.now
    puts "Cleaning up evidence storage for dangling agents..."
    collections = db.collection_names
    # keep only collection with _id in the name
    collections.keep_if {|x| x.match /evidence\.[a-f0-9]{24}/}
    collections.each do |coll|
      tid = coll.split('.')[1]
      target = Item.find(tid)
      # calculate the agents of the target (not deleted), the evidence in the collection
      # and subtract the first from the second
      agents = Item.agents.where(deleted: false, path: target.id).collect {|a| a.id.to_s}
      grouped = Evidence.target(tid).collection.aggregate([{ "$group" => { _id: "$aid" }}]).collect {|x| x['_id']}
      deleted_aid_evidence = grouped - agents

      next if deleted_aid_evidence.empty?

      puts
      puts target.name

      pre_size = db[coll].stats['size']
      deleted_aid_evidence.each do |aid|
        count = Evidence.target(tid).where(aid: aid).count
        Evidence.target(tid).where(aid: aid).delete_all
        puts "#{count} evidence deleted"
      end
      post_size = db[coll].stats['size']
      target.restat
      target.get_parent.restat
      puts "#{(pre_size - post_size).to_s_bytes} cleaned up"
    end

    collections = db.collection_names
    # keep only collection with _id in the name
    collections.keep_if {|x| x.match /grid\.[a-f0-9]{24}\.files/}
    collections.each do |coll|
      tid = coll.split('.')[1]
      target = Item.find(tid)
      # calculate the agents of the target (not deleted), the evidence in the collection
      # and subtract the first from the second
      agents = Item.agents.where(deleted: false, path: target.id).collect {|a| a.id.to_s}
      grouped = GridFS.get_distinct_filenames(tid)
      deleted_aid_grid = grouped - agents

      next if deleted_aid_grid.empty?

      puts
      puts "#{target.name} (gridfs)"

      pre_size = db["grid.#{tid}.files"].stats['size'] + db["grid.#{tid}.chunks"].stats['size']
      deleted_aid_grid.each do |aid|
        GridFS.delete_by_agent(aid, tid)
      end
      post_size = db["grid.#{tid}.files"].stats['size'] + db["grid.#{tid}.chunks"].stats['size']
      target.restat
      target.get_parent.restat
      puts "#{(pre_size - post_size).to_s_bytes} cleaned up"
    end

    current_size = total_size - db.stats['dataSize']

    puts "#{current_size.to_s_bytes} saved"
  end

end

end
end
