#
# Mix-in for DB Layer
#

module Proxies

  def proxies
    mysql_query("SELECT * FROM proxy").to_a
  end

  def proxy_set_version(id, version)
    mysql_query("UPDATE proxy SET version = #{version} WHERE proxy_id = #{id}")
  end

  def proxy_add_log(id, time, type, desc)
    mysql_query("INSERT INTO proxylog (proxy_id, type, timestamp, message)
                 VALUES (#{id}, '#{type}', '#{time}', '#{desc}')")
  end

end