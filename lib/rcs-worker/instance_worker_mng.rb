require 'rcs-common/trace'
require 'timeout'

require_relative 'instance_worker'

module RCS::Worker::InstanceWorkerMng
  extend self
  extend RCS::Tracer

  # TODO
  # extend MonitorMixin

  @worker_threads = {}

  # Gets a connection to mongodb. Given a single thread, multiple calls to
  # this method DO NOT create new connections.
  def db
    RCS::Worker::DB.instance.mongo_connection
  end

  def sync(&block)
    @mutex.synchronize(&block)
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

  def worker_thread(agent)
    ident, instance = agent.split(':')
    worker_thread = @worker_threads[agent]

    if worker_thread and worker_thread.alive?
      worker_thread
    else
      thread = Thread.new { RCS::Worker::InstanceWorker.new(instance, ident).run }
      # thread[:started_at] = Time.now
      @worker_threads[agent] = thread
    end
  end

  # def worker_thread_alive?(agent)
  #   worker_thread = @worker_threads[agent]
  #   return false unless worker_thread
  #   return true if worker_thread.alive?
  #   Time.now - worker_thread[:started_at] <= 5
  # end

  def remove_dead_worker_threads
    keys = @worker_threads.keys.dup

    keys.each do |agent|
      return if @worker_threads[agent].alive?
      trace(:info, "Removing dead instance_worker thread #{agent}")
      @worker_threads.reject! { |k, t| k == agent }
    end
  end

  def worker_threads_count
    # TODO: change #alive?
    @worker_threads.select { |agent, thread| thread.alive? }.size
  end

  def setup
    ensure_indexes
  end

  def spawn_worker_threads
    agents.each { |name| worker_thread(name) }
  end

  # TODO
  # def to_s
  #   @worker_threads.inject("") { |str, values| str << "#{values.last.to_s}" }
  # end
end
