#
#  Heartbeat to update the status of the component in the db
#

# relatives
require_relative 'db_layer.rb'
require_relative 'license.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/status'

# system
require 'socket'

module RCS
module DB

class HeartBeat
  extend RCS::Tracer

  def self.perform

    # check the consistency of the license
    LicenseManager.instance.periodic_check
    
    # report our status to the db
    component = "RCS::DB"
    # our local ip address
    begin
      ip = Socket.gethostname
    rescue Exception => e
      ip = 'unknown'
    end

    #TODO: report some useful information
    message = "Idle..."

    # report our status
    status = Status.my_status
    disk = Status.disk_free
    cpu = Status.cpu_load
    pcpu = Status.my_cpu_load(component)

    # create the stats hash
    stats = {:disk => disk, :cpu => cpu, :pcpu => pcpu}

    # send the status to the db
    DB.instance.status_update component, ip, status, message, stats

    # check the status of other components
    DB.instance.status_check
  end
end

end #Collector::
end #RCS::