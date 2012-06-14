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

    # the unique ident of this task
    task[:id] = SecureRandom.uuid

    trace :info, "Offload task running: #{task[:name]} [#{task[:id]}]"

    # save the task in the journal for recover purpose
    journal_add task unless task.has_key? :recover

    # every task is a separate thread
    Thread.new do
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
      ensure
        Thread.exit
      end
    end
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
        data = File.open(@journal_file, 'r') {|f| f.read}
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
