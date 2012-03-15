require_relative '../db_layer'

module RCS
module DB

class LogMigration
  extend Tracer

  @@total = 0
  @@size = 0
  @@time = Time.now
  @@start_activity, @@start_target, @@start_agent, @@start_log = nil

  def self.migrate(verbose, activity, exclude, from_mid)
  
    puts "Migrating logs for:"

	  from_mid = from_mid.nil? ? 0 : from_mid.to_i
	
    if activity.upcase == 'ALL'
      activities = Item.where({_kind: 'operation'}).and({:_mid.gt => from_mid}).asc(:_mid)
    else
      activities = Item.where({_kind: 'operation', name: activity}).and({:_mid.gt => from_mid}).asc(:_mid)
    end

    if File.exist?('migration.status')
      starting_point = File.open('migration.status', 'r') {|f| f.read}
      @@start_activity, @@start_target, @@start_agent, @@start_log = starting_point.split(' ').collect {|x| x.to_i}
      puts "RESTARTING FROM: #{starting_point}"
    end

	  buffered_activities = activities.to_a.dup
	
    buffered_activities.each do |act|
	    next if act[:_mid].nil?

      if (@@start_activity and @@start_activity > act[:_mid])
        puts "-> #{act.name} Already Migrated"
        next
      end

	    puts "-> #{act.name}"

      # if exclude is not defined, everything is good
      exclude ||= []
      
      unless exclude.include? act[:name]
        begin
          migrate_single_activity act
        rescue Exception => e
          puts "EXCEPTION #{e.class} : #{e.message}"
        end
        puts "#{@@total} logs (#{@@size.to_s_bytes}) migrated to evidence in #{Time.now - @@time} seconds"
        @@total = 0
        @@size = 0
		    @@time = Time.now
      else
        puts "   SKIPPED"
      end
    end
    
    FileUtils.rm_rf('migration.status') if File.exist?('migration.status')
    
  end
  
  def self.migrate_single_activity(act)
    targets = Item.where({_kind: 'target'}).also_in({path: [act._id]}).asc(:_mid)

	  buffered_targets = targets.to_a.dup
	
    buffered_targets.each do |targ|

      if (@@start_target and @@start_target > targ[:_mid])
        puts "   + #{targ.name} Already Migrated"
        next
      end

      puts "   + #{targ.name}"
      migrate_single_target act, targ
    end
  end

  def self.migrate_single_target(act, targ)

    # delete evidence if already present
    db = Mongoid.database
    db.drop_collection Evidence.collection_name(targ._id.to_s)

    Mongoid.identity_map_enabled = false
    Mongoid.persist_in_safe_mode = false

    # the collection for this target
    ev = Evidence.collection_class(targ._id)
	
    # migrate evidence for each agent
    agents = Item.where({_kind: 'agent'}).also_in({path: [targ._id]}).asc(:_mid)
	
	  buffered_agents = agents.to_a.dup
	
    buffered_agents.each do |a|

      if (@@start_agent and @@start_agent > a[:_mid])
        puts "      * #{a.name} Already Migrated"
        next
      end

      # invoke the garbage collector
      GC.start
	  
      # clear stats for the backdoor
      a.stat.evidence = {}
      a.stat.size = 0
      a.stat.grid_size = 0
      a.save
      
      # delete all files related to the backdoor
      GridFS.delete_by_agent(a[:_id].to_s, targ._id.to_s)

      puts "      * #{a.name}"

      # get the number of logs we have...
      count = DB.instance.mysql_query("SELECT COUNT(*) as count FROM `log` WHERE backdoor_id = #{a[:_mid]};").to_a
      count = count[0][:count]

      @@total += count

      # iterate for every log...
      log_ids = DB.instance.mysql_query("SELECT log_id FROM `log` WHERE backdoor_id = #{a[:_mid]} ORDER BY `log_id` ASC;")
      
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

        # skip already migrated logs
        next if (@@start_log and @@start_log > log_id[:log_id])

        # reset the start log, since from this point the logs for other agents can be less than the saved one
        @@start_log = 0

        begin
          log = DB.instance.mysql_query("SELECT * FROM log LEFT JOIN note ON note.log_id = log.log_id LEFT JOIN blotter_log ON log.log_id = blotter_log.log_id WHERE log.log_id = #{log_id[:log_id]};").to_a.first
          log[:log_id] = log_id[:log_id]
        rescue Mysql2::Error => e
          puts "LOGID: #{log_id[:log_id]} ERROR: #{e.message}"
          next
        end
		
        this_size = log[:longblob1].size + log[:longtext1].size + log[:varchar1].size + log[:varchar2].size + log[:varchar3].size + log[:varchar4].size
        size += this_size
        @@size += this_size

        # calculate how many logs processed in a second or in a processing time of one log (whichever is lower)
        time = Time.now.to_i
        if time != prev_time
          processed = (current - prev_current) / (time - prev_time)
          speed = size / (time - prev_time)
          percentage = current.to_f / count * 100 if count != 0
          prev_time = time
          prev_current = current
          size = 0
        end

        # dont' migrate UPLOAD evidences
        next if log[:type] == 'UPLOAD'

        # persist the current log
        log_type = migrate_single_log(ev, log, targ._id, a[:_id])

        # save the current point of migration
        # this is used in case of failure to restart from here
        File.open('migration.status', 'w') {|f| f.write "#{act._mid} #{targ._mid} #{a._mid} #{log_id[:log_id]}"}

        # stat calculation
        a.stat.evidence ||= {}
        a.stat.evidence[log_type] ||= 0
        a.stat.evidence[log_type] += 1

        # report the status
        print "         #{current} of #{count}  %2.1f %% | #{processed}/sec  #{speed.to_s_bytes}/sec | #{@@size.to_s_bytes}      \r" % percentage
        $stdout.flush
      end

      # after completing print the status
      puts "         #{current} of #{count} | 100 %                                                                               "

      # save the stat in the agent
      a.save
    end
  end

  def self.migrate_single_log(ev, log, target_id, agent_id)

	  evidence = ev.create() do |e|
      # migrated log will be identified in the create_callback
      # and the stats will not be calculated on them
      e[:_mid] = log[:log_id]

      e.da = log[:acquired].to_i
      e.dr = log[:received].to_i

      # avoid windows epoch (1601-01-01) replacing with unix epoch (1970-01-01)
      e.da = 0 if e.da < 0

      e.type = log[:type].downcase
      e.rel = log[:tag]
      e.blo = log[:blotter_id].nil? ? false : true
      e.note = log[:content] unless log[:content].nil?
      e.aid = agent_id.to_s

      # parse log specific data
      e.data = migrate_data(log)

      # unify the files evidence
      e.data[:size] = log[:longblob1].bytesize if e.type == 'filecap'
      e.type = 'file' if e.type == 'filecap' or e.type == 'fileopen' or e.type == 'download'

      # unify mail, sms, mms
      e.type = 'message' if e.type == 'mail' or e.type == 'sms' or e.type == 'mms'

      # rename it
      e.type = 'screenshot' if e.type == 'snapshot'
      e.type = 'position' if e.type == 'location'

      # save the binary data
      if log[:longblob1].bytesize > 0
        e.data[:_grid_size] = log[:longblob1].bytesize
        e.data[:_grid] = GridFS.put(log[:longblob1], {filename: agent_id.to_s}, target_id.to_s)
      end
    end

    return evidence.type
  end


  def self.migrate_data(log)
    data = {}
    conversion = {}
    
    # parse log specific data
    case log[:type]
      when 'ADDRESSBOOK'
        conversion = {:varchar1 => :name, :varchar2 => :contact, :longtext1 => :info}
      when 'APPLICATION'
        conversion = {:varchar1 => :program, :varchar2 => :action, :longtext1 => :desc}
      when 'CALENDAR'
        conversion = {:varchar1 => :event, :varchar2 => :type, :int1 => :begin, :int2 => :end, :longtext1 => :info}
      when 'CALL'
        conversion = {:varchar1 => :peer, :varchar2 => :program, :int1 => :duration, :int3 => :status}
      when 'CAMERA'
        conversion = {}
      when 'CHAT'
        conversion = {:varchar1 => :program, :varchar2 => :topic, :varchar3 => :peer, :longtext1 => :content}
      when 'CLIPBOARD'
        conversion = {:varchar1 => :program, :varchar2 => :window, :longtext1 => :content}
      when 'DEVICE'
        conversion = {:longtext1 => :content}
      when 'DOWNLOAD'
        conversion = {:varchar1 => :path}
      when 'FILECAP'
        conversion = {:varchar1 => :path, :varchar2 => :md5}
      when 'FILEOPEN'
        log[:size] = (log[:int1] << 32) + log[:int2]
        conversion = {:varchar1 => :program, :varchar2 => :path, :int3 => :access, :size => :size}
      when 'FILESYSTEM'
        log[:size] = (log[:int1] << 32) + log[:int2]
        conversion = {:varchar1 => :path, :int3 => :attr, :size => :size}
      when 'INFO'
        conversion = {:longtext1 => :content}
      when 'KEYLOG'
        conversion = {:varchar1 => :program, :varchar2 => :window, :longtext1 => :content}
      when 'LOCATION'
        case log[:varchar2]
          when 'IPv4'
            conversion = {:varchar1 => :ip, :varchar2 => :type}
          when 'WIFI'
            log[:wifi] = log[:varchar1].split("\n")
            conversion = {:wifi => :wifi, :varchar2 => :type}
          when 'GSM', 'CDMA'
            log[:cell] = log[:varchar1].split("\n")
            conversion = {:cell => :cell, :varchar2 => :type}
          when 'GPS'
            log[:latitude], log[:longitude] = log[:varchar1].split(' ') unless log[:varchar1].nil?
            conversion = {:latitude => :latitude, :longitude => :longitude, :varchar2 => :type}
        end
      when 'MAIL', 'MMS', 'SMS'
        conversion = {:varchar1 => :from, :varchar2 => :rcpt, :varchar3 => :subject, :int1 => :size, :int2 => :status, :longtext1 => :content}
      when 'MIC'
        conversion = {:int1 => :duration, :int3 => :status}
      when 'MOUSE'
        conversion = {:varchar1 => :program, :varchar2 => :window, :int2 => :x, :int3 => :y, :varchar3 => :resolution}
      when 'PASSWORD'
        conversion = {:varchar1 => :program, :varchar2 => :service, :varchar3 => :pass, :varchar4 => :user}
      when 'PRINT'
        conversion = {:varchar1 => :spool} #, :longtext1 => :ocr}
      when 'SNAPSHOT'
        conversion = {:varchar1 => :program, :varchar2 => :window} #, :longtext1 => :ocr}
      when 'URL'
        conversion = {:varchar1 => :url, :varchar2 => :browser, :varchar3 => :title, :varchar4 => :keywords}#, :longtext1 => :ocr}
    end

    conversion.each_pair do |k, v|
      data[v] = log[k]
    end

    # post processing for location parsing to new format
    if data[:wifi]
      data[:wifi].each_index do |index|
        re = '((?:[0-9A-F][0-9A-F]:){5}(?:[0-9A-F][0-9A-F]))(?![:0-9A-F]) \\[([-+]\\d+)\\] (.*)'
        m = Regexp.new(re, Regexp::IGNORECASE).match(data[:wifi][index])
        wifi = {:mac => m[1], :sig => m[2].to_i, :bssid => m[3]} unless m.nil?
        data[:wifi][index] = wifi
      end
    end

    if data[:cell]
      data[:cell].each_index do |index|
        if data[:type] == 'GSM'
          re = "MCC:(\\d+) MNC:(\\d+) LAC:(\\d+) CID:(\\d+) dBm:([-+]\\d+) ADV:(\\d+) AGE:(\\d+)"
          m = Regexp.new(re, Regexp::IGNORECASE).match(data[:cell][index])
          cell = {:mcc => m[1].to_i, :mnc => m[2].to_i, :lac => m[3].to_i, :cid => m[4].to_i, :db => m[5].to_i, :adv => m[6].to_i, :age => m[7].to_i} unless m.nil?
        end
        if data[:type] == 'CDMA'
          re = "MCC:(\\d+) SID:(\\d+) NID:(\\d+) BID:(\\d+) dBm:([-+]\\d+) ADV:(\\d+) AGE:(\\d+)"
          m = Regexp.new(re, Regexp::IGNORECASE).match(data[:cell][index])
          cell = {:mcc => m[1].to_i, :sid => m[2].to_i, :nid => m[3].to_i, :bid => m[4].to_i, :db => m[5].to_i, :adv => m[6].to_i, :age => m[7].to_i} unless m.nil?
        end
        data[:cell][index] = cell
      end
    end

    # keep the subtype into messages
    if log[:type] == 'mail' or log[:type] == 'sms' or log[:type] == 'mms'
      data[:type] = log[:type]
    end

    return data
  end

end

end # ::DB
end # ::RCS
