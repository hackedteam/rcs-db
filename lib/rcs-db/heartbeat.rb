#
#  Heartbeat to update the status of the component in the db
#

# relatives
require_relative 'db_layer'
require_relative 'license'
require_relative 'shard'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/systemstatus'

# system
require 'socket'

module RCS
module DB

class HeartBeat
  extend RCS::Tracer

  def self.perform

    # reset the status
    SystemStatus.my_status = 'OK'
    SystemStatus.my_error_msg = nil

    # check the consistency of the license
    LicenseManager.instance.periodic_check

    # check the status of the DB shards
    check_shards

    # report our status to the db
    component = "RCS::DB"
    # our local ip address
    begin
      ip = Socket.gethostname
    rescue Exception => e
      ip = 'unknown'
    end

    #TODO: report some useful information
    message = SystemStatus.my_error_msg || "Idle..."

    # report our status
    status = SystemStatus.my_status
    disk = SystemStatus.disk_free
    cpu = SystemStatus.cpu_load
    pcpu = SystemStatus.my_cpu_load(component)

    # create the stats hash
    stats = {:disk => disk, :cpu => cpu, :pcpu => pcpu}

    begin
    # send the status to the db
    ::Status.status_update component, ip, status, message, stats
    # check the status of other components
    ::Status.status_check
    rescue Exception => e
      trace :fatal, "Cannot perform status update: #{e.message}"
    end
  end

  def self.check_shards
    begin
    shards = Shard.all
    shards['shards'].each do |shard|
      status = Shard.find(shard['_id'])
      if status['ok'] == 0
        trace :fatal, "Heartbeat shard check: #{status['errmsg']}"
        SystemStatus.my_status = 'ERROR'
        SystemStatus.my_error_msg = status['errmsg']
      end
    end
    rescue Exception => e
      trace :fatal, "Cannot perform shard check: #{e.message}"
    end
  end
end

end #Collector::
end #RCS::