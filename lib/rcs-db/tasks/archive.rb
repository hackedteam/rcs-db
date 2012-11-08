require_relative '../tasks'

module RCS
module DB

class ArchiveTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    @item = ::Item.find(@params['_id'])

    steps = 0

    # calculate the number of selected steps
    ['backup', 'clean', 'close', 'destroy'].each {|key| steps += 1 if @params[key]}

    return steps + 2
  end
  
  def next_entry
    yield @description = "Archiving #{@item[:name]}"

    if @params['backup']
      @description = "Backup in progress..."
      yield do_backup
    end
    if @params['clean']
      @description = "Deleting live data..."
      yield do_clean
    end
    if @params['close']
      @description = "Closing..."
      yield do_close
    end
    if @params['destroy']
      @description = "Destroying #{@item[:name]}"
      yield do_destroy
    end

    yield @description = "#{@item[:name]} archived successfully"
  end


  def do_backup
    trace :info, "Creating backup for #{@item._kind} #{@item.name}"

    # create a fake backup job to handle the process
    backup = ::Backup.new
    backup.name = "Archive_#{@item.name.gsub(' ', '')}"
    backup.what = "#{@item._kind}:#{@item._id}"

    # perform the backup job
    BackupManager.do_backup(Time.now.getutc, backup, false)

    raise "Error while performing backup" if backup.status != 'COMPLETED'
  end

  def do_clean
    # take the item and subitems contained in it
    ::Item.any_of({_id: @item._id}, {path: @item._id}).each do |item|
      next if item._kind != 'target'
      trace :info, "Cleaning #{item.name} - #{item._id}"

      item.drop_evidence_collections
      item.create_evidence_collections
    end
    # restat all the subitem statistics
    ::Item.any_of({_id: @item._id}, {path: @item._id}).each do |item|
      item.restat
    end
  end

  def do_close
    trace :info, "Closing #{@item._kind} #{@item.name}"

    @item.status = 'closed'
    @item.save
  end

  def do_destroy
    trace :info, "Destroying #{@item._kind} #{@item.name}"

    @item.destroy
  end
end

end # DB
end # RCS