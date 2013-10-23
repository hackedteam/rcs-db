require_relative '../tasks'

module RCS
module DB

class RestoreTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    3
  end
  
  def next_entry

    yield @description = "Restoring backup #{@params['id']}"

    BackupManager.restore_backup({'_id' => @params['id']}) do
      sleep 1
      yield
      @description = "Recalculating statistics"
    end

    @description = "Backup restored successfully"
  end
end

end # DB
end # RCS