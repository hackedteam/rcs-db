#
# Controller for Backups
#


module RCS
module DB

class BackupjobController < RESTController

  def index
    require_auth_level :sys
    require_auth_level :sys_backup

    mongoid_query do

      backups = ::Backup.all

      return ok(backups)
    end
  end

  def create
    require_auth_level :sys
    require_auth_level :sys_backup

    mongoid_query do
      b = ::Backup.new
      b.enabled = @params['enabled'] ? true : false
      b.what = @params['what']
      b.when = @params['when']
      b.name = @params['name']
      b.incremental = @params['incremental']
      b.lastrun = ""
      b.status = 'QUEUED'
      b.save
      
      Audit.log :actor => @session[:user][:name], :action => 'backupjob.create', :desc => "#{@params['what']} on #{@params['when']} -> #{@params['name']}"

      return ok(b)
    end    
  end

  def run
    require_auth_level :sys
    require_auth_level :sys_backup

    mongoid_query do
      backup = ::Backup.find(@params['_id'])

      # defer it since it can take long time
      Thread.new do
        begin
          BackupManager.do_backup Time.now.getutc, backup
        ensure
          Thread.exit
        end
      end

      return ok(backup)
    end
  end

  def update
    require_auth_level :sys
    require_auth_level :sys_backup

    mongoid_query do
      backup = ::Backup.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|

        # modifying the incremental flag, reset the ids
        if key == 'incremental'
          backup.incremental_ids = {}
          backup.save
        end

        if backup[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'backupjob.update', :desc => "Updated '#{key}' to '#{value}' for backup #{backup[:name]}"
        end
      end

      backup.update_attributes(@params)

      return ok(backup)
    end
  end

  def destroy
    require_auth_level :sys
    require_auth_level :sys_backup

    mongoid_query do
      backup = ::Backup.find(@params['_id'])
      Audit.log :actor => @session[:user][:name], :action => 'backupjob.destroy', :desc => "Deleted the backup job [#{backup[:name]}]"
      backup.destroy

      return ok
    end
  end

end

class BackuparchiveController < RESTController

  def index
    require_auth_level :sys
    require_auth_level :sys_backup

    index = BackupManager.backup_index

    return ok(index)
  end

  def destroy
    require_auth_level :sys
    require_auth_level :sys_backup

    real = File.realdirpath Config.instance.global['BACKUP_DIR'] + "/" + @params['_id']

    # prevent escaping from the directory
    if not real.start_with? File.realdirpath(Config.instance.global['BACKUP_DIR'] + "/") or not File.exist?(real)
      return conflict("Invalid backup")
    end

    # recursively delete the directory
    FileUtils.rm_rf(real)

    Audit.log :actor => @session[:user][:name], :action => 'backup.destroy', :desc => "Deleted the backup #{@params['_id']} from the archive"

    return ok()
  end

  def restore
    require_auth_level :sys
    require_auth_level :sys_backup

    ret = BackupManager.restore_backup(@params)

    Audit.log :actor => @session[:user][:name], :action => 'backup.restore', :desc => "Restored the backup #{@params['_id']} from the archive"

    if ret
      return ok()
    else
      return server_error("Cannot restore backup")
    end
    
  end

end

end #DB::
end #RCS::