#
# Manage the long running operations with a persisted journal
#

require 'securerandom'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class OffloadManager
  include Singleton
  include RCS::Tracer

  def initialize
    @semaphore = Mutex.new
    @journal = []
    @journal_file = Config.instance.file('task_journal')
  end

  def recover
    trace :debug, "OffloadManager: recovering tasks..."

    # read the journal from filesystem
    journal_read

    # restart all the pending tasks
    @journal.each do |task|
      trace :info, "Recovering offload task #{task[:name]} [#{task[:id]}]"
      task[:recover] = true
      run task
    end
  end

  def run(task)

    # recovered task already have the id and are in the journal
    unless task.has_key? :recover
      # the unique ident of this task
      task[:id] = SecureRandom.uuid
      # save the task in the journal for recover purpose
      journal_add task
    end

    trace :info, "Offload task running: #{task[:name]} [#{task[:id]}]"

    job = lambda do
      begin
        # perform the task
        unless task[:method].nil?
          eval("#{task[:method]}(#{task[:params]})")
        end

        # we have finished, remove from journal
        journal_del task

        trace :info, "Offload task completed: #{task[:name]} [#{task[:id]}]"
      rescue Exception => e
        trace :error, "Cannot perform offload task: #{e.message}"
        trace :fatal, "backtrace: " + e.backtrace.join("\n")
      end
    end

    # if we are recovering just perform the task waiting for it to finish
    # this is more safe than executing all the task in parallel
    # but will increase the starting time of the db. it will not be ready
    # until all the task are recovered
    job.call if task.has_key? :recover

    # every task is a separate thread during normal activity
    # this method is called by threads that need to return as quick as possible
    Thread.new { job.call; Thread.exit } unless task.has_key? :recover
  end

  def add_task(task)
    # the unique ident of this task
    task[:id] = SecureRandom.uuid

    trace :info, "Offload add task : #{task[:name]} [#{task[:id]}]"

    journal_add(task)

    return task
  end

  def remove_task(task)
    trace :info, "Offload remove task : #{task[:name]} [#{task[:id]}]"

    journal_del(task)
  end

  def journal_add(task)
    @semaphore.synchronize do
      @journal.push task
      journal_write
    end
  end

  def journal_del(task)
    @semaphore.synchronize do
      @journal.delete_if {|t| t[:id] == task[:id]}
      journal_write
    end
  end

  def journal_write
    File.open(@journal_file, 'wb') {|f| f.write Marshal.dump(@journal)}
  end

  def journal_read
    if File.exist? @journal_file
      begin
        data = File.open(@journal_file, 'rb') {|f| f.read}
        @journal = Marshal.load(data)
      rescue Exception => e
        trace :warn, "Task journal file is corrupted, deleting it..."
        FileUtils.rm_rf(@journal_file)
      end
    else
      @journal = []
    end
  end

end


end #DB::
end #RCS::
