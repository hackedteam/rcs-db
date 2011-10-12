#
# Controller for Backups
#


module RCS
module DB

class BackupjobController < RESTController

  def index
    require_auth_level :sys

    mongoid_query do

      backups = ::Backup.all

      return RESTController.reply.ok(backups)
    end
  end

  def create
    require_auth_level :sys

    mongoid_query do
      b = ::Backup.new
      b.enabled = @params['enabled'] == true ? true : false
      b.what = @params['what']
      b.when = @params['when']
      b.name = @params['name']
      b.lastrun = ""
      b.status = 'QUEUED'
      b.save
      
      Audit.log :actor => @session[:user][:name], :action => 'backupjob.create', :desc => "#{@params['what']} on #{@params['when']} -> #{@params['name']}"

      return RESTController.reply.ok(b)
    end    
  end

  def run
    require_auth_level :sys
    mongoid_query do
      backup = ::Backup.find(@params['_id'])

      BackupManager.do_backup Time.now.getutc, backup

      return RESTController.reply.ok(backup)
    end
  end

  def update
    require_auth_level :sys

    mongoid_query do
      backup = ::Backup.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if backup[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'backupjob.update', :desc => "Updated '#{key}' to '#{value}' for backup #{backup[:name]}"
        end
      end

      backup.update_attributes(@params)

      return RESTController.reply.ok(backup)
    end
  end

  def destroy
    require_auth_level :sys
    
    mongoid_query do
      backup = ::Backup.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'backupjob.destroy', :desc => "Deleted the backup job [#{backup[:name]}]"
      backup.destroy

      return RESTController.reply.ok
    end
  end

end

class BackuparchiveController < RESTController

  def index
    require_auth_level :sys

    index = []

    Dir[Config.instance.global['BACKUP_DIR'] + '/*'].each do |dir|
      dirsize = 0
      Find.find(dir + '/rcs') { |f| dirsize += File.stat(f).size }
      name = File.basename(dir).split('-')[0]
      time = File.stat(dir).ctime.getutc
      index << {_id: File.basename(dir), name: name, when: time.strftime('%Y-%m-%d %H:%M'), size: dirsize}
    end

    return RESTController.reply.ok(index)
  end

  def destroy
    require_auth_level :sys

    real = File.realdirpath Config.instance.global['BACKUP_DIR'] + "/" + @params['_id']

    # prevent escaping from the directory
    if not real.start_with? Config.instance.global['BACKUP_DIR'] + "/" or not File.exist?(real)
      return RESTController.reply.conflict("Invalid backup")
    end

    # recursively delete the directory
    FileUtils.rm_rf(real)

    Audit.log :actor => @session[:user][:name], :action => 'backup.destroy', :desc => "Deleted the backup #{@params['_id']} from the archive"

    return RESTController.reply.ok()
  end

  def restore
    require_auth_level :sys

    command = Config.mongo_exec_path('mongorestore')
    command += " --drop" if @params['drop']
    command += " #{Config.instance.global['BACKUP_DIR']}/#{@params['_id']}"

    Audit.log :actor => @session[:user][:name], :action => 'backup.restore', :desc => "Restored the backup #{@params['_id']} from the archive"

    if system command
      return RESTController.reply.ok()
    else
      return RESTController.reply.server_error("Cannot restore backup")
    end
    
  end

end

end #DB::
end #RCS::