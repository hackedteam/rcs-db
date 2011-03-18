#
# Mix-in for DB Layer
#

module Status

  # updates or insert the status of a component
  def status_update(component, ip, status, message, stats)

    trace :debug, "#{component}, #{ip}, #{status}, #{message}, #{stats}"

    result = mysql_query("SELECT `monitor_id` FROM monitor WHERE `monitor` = '#{component}' AND remoteip = '#{ip}'")

    result.each do |row|
      mysql_query("UPDATE `monitor` SET `timestamp` = UTC_TIMESTAMP(),
                                        `status` = '#{status}',
                                        `desc` = '#{message}',
                                        `disk` = #{stats[:disk]},
                                        `cputotal` = #{stats[:cpu]},
                                        `cpuprocess` = #{stats[:pcpu]}
                   WHERE `monitor_id` = #{row[:monitor_id]}")
    end

    # the component is not preset, create it
    if result.count == 0 then
      mysql_query("INSERT INTO monitor (`monitor`, `remoteip`, `timestamp`, `status`, `desc`, `disk`, `cputotal`, `cpuprocess`)
                   VALUES ('#{component}', '#{ip}', UTC_TIMESTAMP(), '#{status}', '#{message}', #{stats[:disk]}, #{stats[:cpu]}, #{stats[:pcpu]})")
    end

  end

  # remove a component from the table
  def status_del(id)
    mysql_query("DELETE FROM monitor WHERE monitor_id = #{id}")
  end

  # get the list of all components' statuses
  def status_get

    mysql_query("SELECT * FROM monitor").each do |row|
      #TODO: return the results...
      puts row.inspect
    end
    
  end

end
