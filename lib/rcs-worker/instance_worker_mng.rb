require 'rcs-common/trace'
require 'timeout'
require 'monitor'

require_relative 'instance_worker'

module RCS::Worker::InstanceWorkerMng
  extend MonitorMixin
  extend RCS::Tracer
  extend self

  # Note: synchronize access to
  # @worker_threads using #mon_synchronize
  @worker_threads = {}

  def db
    RCS::Worker::DB.instance.mongo_connection
  end

  def collection
    @collection ||= db.collection('grid.evidence.files')
  end

  def agents
    collection.distinct(:filename)
  end

  def ensure_indexes
    collection.create_index({filename: 1}, {background: 1})
  end

  def spawn_worker_thread(agent)
    ident, instance = agent.split(':')

    mon_synchronize do
      worker_thread = @worker_threads[agent]

      if worker_thread and worker_thread.alive?
        worker_thread
      else
        @worker_threads[agent] = Thread.new { RCS::Worker::InstanceWorker.new(instance, ident).run }
      end
    end

  rescue ThreadError, NoMemoryError => error
    msgs = ["[#{error.class}] #{error.message}."]
    msgs << "There are #{Thread.list.size} active threads. EventMachine threadpool_size is #{EM.threadpool_size}."
    msgs.concat(error.backtrace) if error.backtrace.respond_to?(:concat)

    trace(:fatal, msgs.join("\n"))
    exit!(1) # Die hard (will be restarted by windows service manager)
  end

  def remove_dead_worker_threads
    mon_synchronize do
      keys = @worker_threads.keys.dup

      keys.each do |agent|
        return if @worker_threads[agent].alive?
        trace(:debug, "Removing dead instance_worker thread #{agent}")
        @worker_threads.reject! { |k, t| k == agent }
      end
    end
  end

  def worker_threads_count
    mon_synchronize do
      @worker_threads.select { |agent, thread| thread.alive? }.size
    end
  end

  def setup
    ensure_indexes
  end

  def spawn_worker_threads
    count = agents.count
    trace :info, "Restarting processing evidence for #{count} agents in queue" if count > 0
    agents.each { |name| spawn_worker_thread(name) }
  end
end
