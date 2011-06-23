require 'rcs-db/db_layer'

module RCS
module DB

class AlertMigration
  extend Tracer
  
  def self.migrate(verbose)
  
    print "Migrating alerts "

    alerts = DB.instance.mysql_query('SELECT * from `alert` ORDER BY `alert_id`;').to_a
    alerts.each do |alert|

      # skip item if already migrated
      next if Alert.count(conditions: {_mid: alert[:alert_id]}) != 0

      print "." unless verbose
      
      ma = ::Alert.new
      ma[:_mid] = alert[:alert_id]
      ma.type = alert[:type].downcase
      ma.evidence = alert[:log_type].downcase
      ma.keywords = alert[:log_pattern]
      ma.suppression = alert[:suppression]
      ma.priority = alert[:tag]
      ma.enabled = true
      
      operation = ::Item.where({_mid: alert[:activity_id], _kind: 'operation'}).first
      target = ::Item.where({_mid: alert[:target_id], _kind: 'target'}).first
      backdoor = ::Item.where({_mid: alert[:backdoor_id], _kind: 'backdoor'}).first

      ma.path = []
      ma.path << operation[:_id] unless operation.nil?
      ma.path << target[:_id] unless target.nil?
      ma.path << backdoor[:_id] unless backdoor.nil?

      user = ::User.where({_mid: alert[:user_id]}).first
      user.alerts << ma

    end
    
    puts " done."
    
  end

end

end # ::DB
end # ::RCS
