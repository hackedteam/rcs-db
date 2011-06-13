require 'rcs-db/db_layer'

module RCS
module DB

class LogMigration
  extend Tracer

  @@total = 0

  def self.migrate(verbose, activity)
  
    puts "Migrating logs for:"

    if activity.upcase == 'ALL' then
      activities = Item.where({_kind: 'operation'})
    else
      activities = Item.where({_kind: 'operation', name: activity})
    end

    activities.each do |act|
      puts "-> #{act.name}"
      migrate_single_activity act[:_id]
    end

    puts "#{@@total} logs migrated to evidence."
  end

  def self.migrate_single_activity(id)
    targets = Item.where({_kind: 'target'}).also_in({_path: [id]})

    targets.each do |targ|
      puts "   + #{targ.name}"
      migrate_single_target targ[:_id]
    end
  end

  def self.migrate_single_target(id)
    backdoors = Item.where({_kind: 'backdoor'}).also_in({_path: [id]})

    backdoors.each do |bck|
      puts "      * #{bck.name}"

      # get the number of logs we have...
      count = DB.instance.mysql_query("SELECT COUNT(*) as count FROM `log` WHERE backdoor_id = #{bck[:_mid]};").to_a
      count = count[0][:count]

      @@total += count

      # iterate for every log...
      log_ids = DB.instance.mysql_query("SELECT log_id FROM `log` WHERE backdoor_id = #{bck[:_mid]} ORDER BY `log_id`;")
      
      current = 0
      print "         #{current} of #{count} | 0 %\r"

      prev_time = Time.now.to_i
      prev_current = 0
      processed = 0
      percentage = 0
      
      log_ids.each do |log_id|
        current = current + 1
        log = DB.instance.mysql_query("SELECT log_id, remotehost FROM `log` WHERE log_id = #{log_id[:log_id]};")

        # calculate how many logs processed in one second
        time = Time.now.to_i
        if time != prev_time then
          processed = current - prev_current
          prev_time = time
          prev_current = current
          percentage = current.to_f / count * 100 if count != 0
        end

        #TODO: insert the evidence

        # report the status
        print "         #{current} of #{count} | %2.1f %%   #{processed}/sec     \r" % percentage
        $stdout.flush
      end
      # after completing print the status
      puts "         #{current} of #{count} | 100 %                         "
    end
  end

end

end # ::DB
end # ::RCS
