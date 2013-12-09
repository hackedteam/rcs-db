require 'rcs-common/trace'
require 'timeout'

require_relative 'instance_worker'

module RCS::Worker::QueueManager
  extend RCS::Tracer
  extend self

  @active_workers = {}
  @last_evidence_id = "0"

  def shard
    @shard ||= RCS::DB::Config.instance.global['SHARD']
  end

  # Gets a connection to mongodb. Given a single thread, multiple calls to
  # this method DO NOT create new connections.
  def db
    RCS::Worker::DB.instance.mongo_connection
  end

  def close_mongo_connection
    db.connection.close rescue nil
  end

  # Gets all the new evidece
  def new_evidence_list
    retry_on_timeout do
      db.collection('grid.evidence.files').find({}, {sort: ["_id", :asc]})
    end
  end

  # Use this method when accessing mongodb
  def retry_on_timeout
    Timeout::timeout(5) { yield }
  rescue Timeout::Error
    trace :warn, "Stucked while accessing mongodb, retrying..."
    close_mongo_connection
    retry
  end

  def run!
    in_a_safe_loop do
      new_evidence_list.each { |evidence| process_evidence(evidence) }
    end
  end

  # Execute the given block every second and DO NOT quit the loop
  # on any exception
  def in_a_safe_loop(&block)
    loop do
      begin
        yield
        sleep(1)
      rescue Interrupt
        trace :info, "System shutdown. Bye bye!"
        return 0
      rescue Exception => ex
        close_mongo_connection
        trace :error, ex.message
        trace :fatal, "EXCEPTION: [#{ex.class}] #{ex.message}\n#{ex.backtrace.join("\n")}"
      end
    end
  end

  def process_evidence(evidence)
    id = evidence['_id'].to_s
    ident, instance = evidence['filename'].to_s.split(":")

    return if id.blank? or ident.blank? or instance.blank?

    enqueue_evidence(instance, ident, id)
  end

  # Spawns a thread for each agent and sends the current evidence to that thread
  def enqueue_evidence(instance, ident, id)
    return if @last_evidence_id >= id
    uid = "#{ident}:#{instance}"

    trace :debug, "Send evidence #{id} to instance worker #{uid}"

    @active_workers[uid] ||= RCS::Worker::InstanceWorker.new(instance, ident)
    @active_workers[uid].queue(id)

    @last_evidence_id = id
  rescue Exception => ex
    trace(:error, ex.message)
  end

  def how_many_processing
    @active_workers.select { |k, processor| processor.state == :running }.size
  end

  def to_s
    @active_workers.inject("") { |str, values| str << "#{values.last.to_s}" }
  end
end
