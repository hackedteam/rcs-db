#
# Mix-in for DB Layer
#

module DBLayer
module Status

  ERROR = '2'

  # updates or insert the status of a component
  def status_update(name, address, status, info, stats)

    #trace :debug, "#{name}, #{address}, #{status}, #{info}, #{stats}"

    monitor = ::Status.find_or_create_by(name: name, address: address)

    monitor[:info] = info
    monitor[:pcpu] = stats[:pcpu]
    monitor[:cpu] = stats[:cpu]
    monitor[:disk] = stats[:disk]
    monitor[:time] = Time.now.getutc.to_i
    case(status)
      when 'OK'
        monitor[:status] = '0'
      when 'WARN'
        monitor[:status] = '1'
      when 'ERROR'
        monitor[:status] = '2'
    end

    monitor.save
  end

  def status_check
    monitors = ::Status.all

    monitors.each do |m|
      # a component is marked failed after 2 minutes (if not already marked)
      if Time.now.getutc.to_i - m[:time] > 120 and m[:status] != ERROR
        m[:status] = ERROR
        # TODO: send alerting mail
        trace :warn, "Component #{m[:name]} is not responding, marking failed..."
        m.save
      end
    end

  end

end # ::Status
end # ::DBLayer