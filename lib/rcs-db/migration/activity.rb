require 'rcs-db/db_layer'

module RCS
module DB

class ActivityMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating activities " unless verbose

    activities = DB.instance.mysql_query('SELECT * from `activity` ORDER BY `activity_id`;').to_a
    activities.each do |a|

      trace :info, "Migrating activity '#{a[:activity]}'." if verbose
      print "." unless verbose
      
      # skip item if already migrated
      next if Item.count(conditions: {_mid: a[:activity_id], _kind: 'activity'}) != 0
      
      ma = ::Item.new
      ma[:_mid] = a[:activity_id]
      ma.name = a[:activity]
      ma.contact = a[:contact]
      ma.desc = a[:desc]
      ma._kind = 'activity'
      ma._path = []
      ma.status = a[:status].downcase
      ma.save
    end
    
    puts " done." unless verbose
    
  end

  def self.migrate_associations(verbose)
     print "Associating activities to groups " unless verbose
    
    associations = DB.instance.mysql_query('SELECT * from `activity_group` ORDER BY `activity_id`;').to_a
    associations.each do |a|
      activity = Item.where({_mid: a[:activity_id], _kind: 'activity'}).first
      group = Group.where({_mid: a[:group_id]}).first
      group.items << activity
      
      trace :info, "Associating activity '#{activity.name}' to group '#{group.name}'." if verbose
      print "." unless verbose
      
    end
    
    puts " done." unless verbose
  end
end

end # ::DB
end # ::RCS
