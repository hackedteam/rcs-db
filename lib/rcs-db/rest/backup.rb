#
# Controller for Backups
#


module RCS
module DB

class BackupController < RESTController

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
      b.lastrun = 0
      b.status = 'QUEUED'
      b.save
      
      Audit.log :actor => @session[:user][:name], :action => 'backup.create', :desc => "#{@params['what']} on #{@params['when']} -> #{@params['name']}"

      return RESTController.reply.ok(b)
    end    
  end

  def update
    require_auth_level :sys

    mongoid_query do
      backup = ::Backup.find(@params['_id'])
      @params.delete('_id')

      @params.each_pair do |key, value|
        if backup[key.to_s] != value
          Audit.log :actor => @session[:user][:name], :action => 'backup.update', :desc => "Updated '#{key}' to '#{value}' for backup #{backup[:_id]}"
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
      Audit.log :actor => @session[:user][:name], :action => 'backup.destroy', :desc => "Deleted the backup [#{@params['what']} on #{@params['when']}]"
      backup.destroy

      return RESTController.reply.ok
    end
  end

end

end #DB::
end #RCS::