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

class Migration

  def self.up_to(version)
    puts "migrating to #{version}"

    run [:mongoid3, :access_control, :reindex_aggregates] if version >= '8.3.2'
    run [:reindex_queues, :drop_sessions] if version >= '8.3.3'
    run [:gmail_to_mail, :aggregate_summary, :reindex_evidences] if version >= '8.4.0'

    return 0
  end

  def self.run(params)
    puts "Migration procedure started..."

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
    puts "Re-indexing aggregates..."
    ::Item.targets.each do |target|
      target.create_target_collections
      target.create_target_entity

      begin
        next unless Aggregate.target(target._id).exists?
        Aggregate.target(target._id).collection.indexes.drop
        Aggregate.target(target._id).create_collection
        print "\r%d aggregates reindexed" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

  def self.reindex_evidences
    start = Time.now
    count = 0
    puts "Re-indexing evidences..."
    ::Item.targets.each do |target|
      begin
        klass = Evidence.collection_class(target._id)
        next unless klass.exists?
        klass.collection.indexes.drop
        klass.create_collection
        print "\r%d evidences reindexed" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

  def self.reindex_queues
    start = Time.now
    puts "Re-indexing queues..."
    NotificationQueue.queues.each do |queue|
      queue.collection.drop
    end
    # create them
    NotificationQueue.create_queues
    # add index (if already created without indexes)
    NotificationQueue.queues.each do |queue|
      queue.create_indexes
    end
    puts "done in #{Time.now - start} secs"
  end

  def self.aggregate_summary
    start = Time.now
    count = 0
    puts "Creating aggregates summaries..."
    ::Item.targets.each do |target|
      begin
        next if Aggregate.target(target._id).empty?

        Aggregate.target(target._id).rebuild_summary
        print "\r%d summaries" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

  def self.drop_sessions
    puts "Deleting old sessions..."
    ::Session.destroy_all
  end

  def self.gmail_to_mail
    start = Time.now
    count = 0
    puts "Updating aggregates' mail tags..."
    ::Item.targets.each do |target|
      begin
        next if Aggregate.target(target._id).empty?
        Aggregate.target(target._id).where(type: :gmail).each do |agg|
          attr = agg.attributes
          attr['type'] = :mail
          Aggregate.target(target._id).new(attr).save
        end
        Aggregate.target(target._id).where(type: :gmail).destroy_all

        print "\r%d targets" % count += 1
      rescue Exception => e
        puts e.message
      end
    end
    ::Entity.targets.each do |entity|
      next unless entity.handles
      entity.handles.where(type: :gmail).update_all(type: :mail)
    end
    puts
    puts "done in #{Time.now - start} secs"
  end

end

end
end
