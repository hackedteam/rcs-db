#
# Helper for migration between versions
#

require 'mongoid'
require 'set'

require 'rcs-common/trace'

require_relative 'db_objects/group'
require_relative 'config'

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
    puts "Recalculating item checksums..."
    count = 0
    ::Item.each do |item|
      count += 1
      item.cs = item.calculate_checksum
      item.save
      print "\r%d item migrated" % count
    end
    puts
    puts "done"
  end

  def self.access_control
    start = Time.now
    puts "Rebuilding access control..."
    Group.rebuild_access_control
    puts "Access control rebuilt in #{Time.now - start} secs"
  end

end
