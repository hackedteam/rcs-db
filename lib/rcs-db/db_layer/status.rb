#
# Mix-in for DB Layer
#

module Status

  def update_status(component, ip, status, message, stats)
    #TODO: implement update_status
    trace :debug, "#{component}, #{ip}, #{status}, #{message}, #{stats}"
  end
    
end