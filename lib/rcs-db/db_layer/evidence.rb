#
# Mix-in for DB Layer
#

module DBLayer
module Evidence
  
  def evidence_store(evidence)
    trace :info, "storing evidence #{evidence.info}"
    
    case evidence.info[:type]
      when :DEVICE
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired, longtext1)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 0,
                 '#{evidence.info[:backdoor_id]}',
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}',
                 '#{@mysql.escape(evidence.info[:content].to_s)}')"
      else
        q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired)
                 VALUES (0,
                 '#{@mysql.escape(evidence.info[:type].to_s)}',
                 0,
                 31337,
                 '#{@mysql.escape(evidence.info[:source_id])}',
                 '#{@mysql.escape(evidence.info[:device_id])}',
                 '#{@mysql.escape(evidence.info[:user_id])}',
                 '#{@mysql.escape(evidence.info[:received].to_s)}',
                 '#{@mysql.escape(evidence.info[:acquired].to_s)}')"
    end
    
    return mysql_query(q)
  end
  
end # ::Evidence
end # ::DBLayer
