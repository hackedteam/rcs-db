require 'rcs-db/db_layer'

module RCS
module DB

class TargetMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating targets " unless verbose

    targets = DB.instance.mysql_query('SELECT * from `target` ORDER BY `target_id`;').to_a
    targets.each do |target|

      trace :info, "Migrating target '#{target[:target]}'." if verbose
      print "." unless verbose
      
      # skip item if already migrated
      next if Item.count(conditions: {_mid: target[:target_id], _kind: 'target'}) != 0
      
      mt = ::Item.new
      mt[:_mid] = target[:target_id]
      mt.name = target[:target]
      mt.desc = target[:desc]
      mt._kind = 'target'
      mt.status = target[:status].downcase

      activity = Item.where({_mid: target[:activity_id], _kind: 'activity'}).first
      mt._path = [ activity[:_id] ]

      mt.save
    end
    
    puts " done." unless verbose
    
  end
end

end # ::DB
end # ::RCS
