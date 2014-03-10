#
# Helper for migration between versions
#

require 'mongoid'
require 'set'
require 'fileutils'
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

    run [:migrate_scout_to_level] if version >= '9.2.0'

    run [:recalculate_checksums, :drop_sessions, :remove_statuses]
    run [:remove_ni_java_rules] if version >= '9.1.5'
    run [:fill_up_handle_book_from_summary, :move_grid_evidence_to_worker_db] if version >= '9.2.0'

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

  def move_grid_evidence_to_worker_db
    collection_names = %w[grid.evidence.files grid.evidence.chunks]
    go_on_and_migrate = true

    collection_names.each do |name|
      collection = Mongoid.default_session.collections.find { |coll| coll.name == name }

      if collection.nil?
        go_on_and_migrate = false
      elsif collection.find.count.zero?
        go_on_and_migrate = false
        collection.drop rescue nil
      end
    end

    return unless go_on_and_migrate

    temp_folder = File.expand_path('../../../temp', __FILE__)
    Dir.mkdir(temp_folder) unless Dir.exists?(temp_folder)
    temp_folder = "#{temp_folder}/migration"
    FileUtils.rm_rf(temp_folder)
    Dir.mkdir(temp_folder)

    collection_names.each do |name|
      mongodump = RCS::DB::Config.mongo_exec_path('mongodump')
      puts "Dump #{name}"
      command = "#{mongodump} -h localhost -d \"rcs\" -c \"#{name}\" -o \"#{temp_folder}\""
      `#{command}`
    end

    collection_names.each do |name|
      mongorestore = RCS::DB::Config.mongo_exec_path('mongorestore')
      puts "Restore #{name}"
      command = "#{mongorestore} -h localhost -d \"rcs-worker\" -c \"#{name}\" \"#{temp_folder}/rcs/#{name}.bson\""
      `#{command}`
    end
  end

  def fill_up_handle_book_from_summary
    puts "Rebuild handle book"
    HandleBook.rebuild
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

  def remove_ni_java_rules
    ::Injector.each do |ni|
      ni.rules.each do |rule|
        rule.destroy if rule.action.eql? 'INJECT-HTML-JAVA'
      end
    end
  end

  def migrate_scout_to_level
    count = 0
    ::Item.agents.each do |agent|
      begin
        agent.level = (agent[:scout] ? :scout : :elite)
        agent.unset(:scout)
        agent.save
        print "\r%d agents migrated" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
    ::Item.factories.each do |factory|
      factory.unset(:scout)
    end
  end

  def drop_sessions
    ::Session.destroy_all
  end

  def remove_statuses
    ::Status.destroy_all
  end

  def cleanup_storage
    count = 0
    db = DB.instance

    total_size =  db.db_stats['dataSize']

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

      pre_size = db.collection_stats(coll)['size'].to_i
      deleted_aid_evidence.each do |aid|
        count = Evidence.target(tid).where(aid: aid).count
        Evidence.target(tid).where(aid: aid).delete_all
        puts "#{count} evidence deleted"
      end
      post_size = db.collection_stats(coll)['size'].to_i
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

      pre_size = db.collection_stats("grid.#{tid}.files")['size'] + db.collection_stats("grid.#{tid}.chunks")['size']
      deleted_aid_grid.each do |aid|
        GridFS.delete_by_agent(aid, tid)
      end
      post_size = db.collection_stats("grid.#{tid}.files")['size'] + db.collection_stats("grid.#{tid}.chunks")['size']
      target.restat
      target.get_parent.restat
      puts "#{(pre_size - post_size).to_s_bytes} cleaned up"
    end

    current_size = total_size - db.db_stats['dataSize']

    puts "#{current_size.to_s_bytes} saved"
  end

end

end
end
