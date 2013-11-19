# encoding: utf-8
#
#  Heartbeat to update the status of the component in the db
#

require_relative 'queue_manager'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/systemstatus'

# from RCS::DB
if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/db_layer'
else
  require 'rcs-db/db_layer'
end

# system
require 'socket'

module RCS
module Worker

class HeartBeat
  extend RCS::Tracer

  def self.perform
    # reset the status
    SystemStatus.reset

    # report our status to the db
    component = "RCS::Worker"
    # our local ip address
    begin
      ip = Socket.gethostname
    rescue Exception => e
      ip = 'unknown'
    end

    how_many_processing = QueueManager.how_many_processing
    msg = how_many_processing > 0 ? "Processing evidence from #{how_many_processing} agents." : 'Idle...'
    message = SystemStatus.my_error_msg || msg

    # report our status
    status = SystemStatus.my_status

    # create the stats hash
    stats = {:disk => SystemStatus.disk_free, :cpu => SystemStatus.cpu_load, :pcpu => SystemStatus.my_cpu_load(component)}

    begin
      # send the status to the db
      ::Status.status_update component, ip, status, message, stats, 'worker', $version
    rescue Exception => e
      trace :fatal, "Cannot perform status update: #{e.message}"
      trace :fatal, e.backtrace
    end
  ensure
    # Ensure that the mongoid connection is closed at the end
    Mongoid.default_session.disconnect rescue nil
  end
end

end #Collector::
end #RCS::