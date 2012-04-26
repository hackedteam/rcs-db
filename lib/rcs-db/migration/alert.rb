require_relative '../db_layer'

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
      ma.type = alert[:type]
      ma.evidence = alert[:log_type].downcase
      ma.keywords = alert[:log_pattern]
      ma.suppression = alert[:suppression]
      ma.tag = alert[:tag]
      ma.enabled = true
      ma.action = 'EVIDENCE'
      
      operation = ::Item.where({_mid: alert[:activity_id], _kind: 'operation'}).first
      target = ::Item.where({_mid: alert[:target_id], _kind: 'target'}).first
      agent = ::Item.where({_mid: alert[:backdoor_id], _kind: 'agent'}).first

      ma.path = []
      ma.path << operation[:_id] unless operation.nil?
      ma.path << target[:_id] unless target.nil?
      ma.path << agent[:_id] unless agent.nil?

      user = ::User.where({_mid: alert[:user_id]}).first
      user.alerts << ma

    end
    
    puts " done."
    
  end

end

end # ::DB
end # ::RCS
