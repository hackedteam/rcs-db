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
      #next unless now.strftime('%H:%M') == btime['time']

      # check if the day of the month is right
      next if (not btime['month'].empty? and not btime['month'].include? now.mday)

      # check if the day of the week is right
      next if (not btime['week'].empty? and not btime['week'].include? now.wday)

      trace :info, "Performing backup [#{backup.name}]..."

      Audit.log :actor => '<system>', :action => 'backup.start', :desc => "Performing backup #{backup.name}"

      backup.status = 'RUNNING'
      backup.save

      begin
        # retrieve the list of collection and iterate on it to create a backup
        # the 'what' property of a backup decides which collections have to be backed up
        collections = Mongoid::Config.master.collection_names

        # don't backup the statuses of the components
        collections.delete('statuses')
        # don't backup the logs of the components
        collections.delete_if {|x| x['logs.']}

        # remove it here, it will not be dumped in the main cycle
        # we call a dump on it later with grid_filter applied on it
        collections.delete_if {|x| x['fs.']}

        grid_filter = "{}"
        item_filter = "{}"
        params = {what: backup.what, coll: collections, ifilter: item_filter, gfilter: grid_filter}

        case backup.what
          when 'metadata'
            # don't backup evidence collections
            params[:coll].delete_if {|x| x['evidence.']}
            get_global_grid_ids(params)
          when 'full'
            # we backup everything... woah !!
          else
            # backup single item (operation or target)
            partial_backup(params)
        end

        # the command of the mongodump
        mongodump = Config.mongo_exec_path('mongodump')
        mongodump += " -o #{Config.instance.global['BACKUP_DIR']}/#{backup.name}-#{now.strftime('%Y-%m-%d-%H:%M')}"
        mongodump += " -d rcs"

        # create the backup of the collection (common)
        params[:coll].each do |coll|
          if coll == 'items'
            system mongodump + " -c #{coll} -q '#{params[:ifilter]}'"
          else
            system mongodump + " -c #{coll}"
          end
        end

        # gridfs entries linked to backed up collections
        system mongodump + " -c fs.files -q '#{params[:gfilter]}'"
        # use the same query to retrieve the chunk list
        params[:gfilter]['_id'] = 'files_id' unless params[:gfilter]['_id'].nil?
        system mongodump + " -c fs.chunks -q '#{params[:gfilter]}'"

        Audit.log :actor => '<system>', :action => 'backup.end', :desc => "Backup #{backup.name} completed"

      rescue Exception => e
        trace :error, "Backup #{backup.name} failed: #{e.message}"
        backup.status = 'ERROR'
        backup.save
      end

      backup.status = 'COMPLETED'
      backup.save
    end

  end

  def self.get_global_grid_ids(params)

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
    params[:gfilter] = "{\"_id\":{\"$in\": ["
    params[:gfilter].each do |id|
      json_query += "ObjectId(\"#{id}\"),"
    end
    params[:gfilter] += "0]}}"

  end

  def self.partial_backup(params)

    # extract the id from the string
    id = BSON::ObjectId.from_string(params[:what][-24..-1])

    # take the item and subitems contained in it
    items = ::Item.any_of({_id: id}, {path: id})

    raise "cannot perform partial backup: invalid ObjectId" if items.empty?
    
    # remove all the collections except 'items'
    params[:coll].delete_if {|c| c != 'items'}

    # prepare the json query to filter the items
    params[:ifilter] = "{\"_id\":{\"$in\": ["
    items.each do |item|
      params[:ifilter] += "ObjectId(\"#{item._id}\"),"
      # for each target we add to the list of collections the target's evidence
      if item[:_kind] == 'target'
        params[:coll] << "evidence.#{item._id}"
        # TODO: uncomment this
        #params[:coll] << "grid.#{item._id}.files"
        #params[:coll] << "grid.#{item._id}.chunks"
      end
    end
    params[:ifilter] += "0]}}"

  end

end

end #Collector::
end #RCS::