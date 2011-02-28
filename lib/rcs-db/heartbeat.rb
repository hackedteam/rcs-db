#
#  Heartbeat to update the status of the component in the db
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/status'

module RCS
module DB

class HeartBeat
  extend RCS::Tracer

  def self.perform

    # report our status to the db
    component = "RCS::DB"
    # used only by NC
    ip = ''

    message = "Idle..."

    # report our status
    status = Status.my_status
    disk = Status.disk_free
    cpu = Status.cpu_load
    pcpu = Status.my_cpu_load

    # create the stats hash
    stats = {:disk => disk, :cpu => cpu, :pcpu => pcpu}

    # send the status to the db
    #TODO: db layer
    #DB.instance.update_status component, ip, status, message, stats
  end
end

end #Collector::
end #RCS::