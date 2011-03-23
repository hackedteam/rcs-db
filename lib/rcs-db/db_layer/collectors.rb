#
# Mix-in for DB Layer
#

module Collectors

  def collectors
    mysql_query("SELECT * FROM collector").to_a
  end

  def collector_set_version(id, version)
    mysql_query("UPDATE collector SET version = #{version} WHERE collector_id = #{id}")
  end

  def collector_add_log(id, time, type, desc)
    mysql_query("INSERT INTO collectorlog (collector_id, type, timestamp, message)
                 VALUES (#{id}, '#{type}', '#{time}', '#{desc}')")
  end

end