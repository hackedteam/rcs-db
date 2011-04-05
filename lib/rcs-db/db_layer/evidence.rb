#
# Mix-in for DB Layer
#

module DBLayer
module Evidence
  
  def evidence_store(evidence)
    trace :info, "storing evidence #{evidence.info}"
    
    q = "INSERT INTO log (tag, type, flags, backdoor_id, remoteip, remotehost, remoteuser, received, acquired)
                 VALUES (0, '#{evidence.info[:type].to_s}', 0, 31337, '#{evidence.info[:source_id]}', '#{evidence.info[:device_id]}',
                 '#{evidence.info[:user_id]}', '#{evidence.info[:received].to_s}', '#{evidence.info[:acquired].to_s}')"
    
    mysql_query(q)
  end
  
end # ::Evidence
end # ::DBLayer
