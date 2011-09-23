#
#  Heartbeat to update the status of the component in the db
#

# relatives
require_relative 'db_layer'

# from RCS::Common
require 'rcs-common/trace'


module RCS
module DB

class BackupManager
  extend RCS::Tracer

  def self.perform

    now = Time.now

    ::Backup.all.each do |backup|

      btime = backup.when

      # process the backup only if the time is right
      next unless now.strftime('%H:%M') == btime['time']

      # check if the day of the month is right
      next if (not btime['month'].empty? and not btime['month'].include? now.mday)

      # check if the day of the week is right
      next if (not btime['week'].empty? and not btime['week'].include? now.wday)

      trace :info, "Performing backups..."

      pp backup

    end

  end

end

end #Collector::
end #RCS::