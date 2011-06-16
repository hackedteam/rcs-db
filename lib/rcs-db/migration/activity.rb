require 'rcs-db/db_layer'

module RCS
module DB

class ActivityMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating activities to operations"

    activities = DB.instance.mysql_query('SELECT * from `activity` ORDER BY `activity_id`;').to_a
    activities.each do |a|

      # skip item if already migrated
      next if Item.count(conditions: {_mid: a[:activity_id], _kind: 'operation'}) != 0

      trace :info, "Migrating activity '#{a[:activity]}'." if verbose
      print "." unless verbose

      ma = ::Item.new
      ma[:_mid] = a[:activity_id]
      ma.name = a[:activity]
      ma.contact = a[:contact]
      ma.desc = a[:desc]
      ma._kind = 'operation'
      ma._path = []
      ma.status = a[:status].downcase

      ma.stat = Stat.new
      ma.stat.evidence = {}
      ma.stat.size = 0
      ma.stat.grid_size = 0

      ma.save

    end
    
    puts " done."
    
  end

  def self.migrate_associations(verbose)
    print "Associating activities to groups "
    
    associations = DB.instance.mysql_query('SELECT * from `activity_group` ORDER BY `activity_id`;').to_a
    associations.each do |a|
      activity = Item.where({_mid: a[:activity_id], _kind: 'operation'}).first
      group = Group.where({_mid: a[:group_id]}).first

      # skip already migrated associations
      next if group.item_ids.include? activity[:_id]

      group.items << activity
      
      trace :info, "Associating activity '#{activity.name}' to group '#{group.name}'." if verbose
      print "." unless verbose
      
    end
    
    puts " done."
  end
end

end # ::DB
end # ::RCS
