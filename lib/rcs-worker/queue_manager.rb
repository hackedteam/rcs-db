# relatives
require_relative 'instance_worker'

# from RCS::Common
require 'rcs-common/trace'

# from System
require 'singleton'
require 'thread'

module RCS
module Worker

class QueueManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @instances = {}
    @semaphore = Mutex.new
    @polling_mutex = Mutex.new
    @last_id = "0"
  end

  def how_many_processing
    @instances.select {|k, processor| processor.state == :running}.size
  end

  def queue(instance, ident, evidence)
    return nil if instance.nil? or ident.nil? or evidence.nil?

    @semaphore.synchronize do
      idx = "#{ident}:#{instance}"

      begin
        @instances[idx] ||= InstanceWorker.new instance, ident
        @instances[idx].queue(evidence)
      rescue Exception => e
        trace :error, e.message
        return nil
      end
    end
  end

  def to_s
    str = ""
    @instances.each_pair do |idx, processor|
      str += "#{processor.to_s}"
    end
    str
  end

  def check_new
    return if @polling_mutex.locked?

    @polling_mutex.synchronize do
      #trace :debug, "Checking for new evidence..."

      begin
        db = Mongoid.database
        evidences = db.collection('grid.evidence.files').find({metadata: {shard: RCS::DB::Config.instance.global['SHARD']}}, {sort: ["_id", :asc]})
        evidences.each do |ev|

          # don't queue already queued ids.
          # we rely here on the fact the id are ascending
          next if @last_id.to_s >= ev['_id'].to_s

          # get the ident from the filename
          ident, instance = ev['filename'].split(":")

          # queue the evidence
          QueueManager.instance.queue instance, ident, ev['_id'].to_s

          # remember the last processed id
          @last_id = ev['_id']
        end
      rescue Exception => e
        trace :error, "Cannot process pending evidences: #{e.message}"
      end
    end
  end

end

end # ::Worker
end # ::RCS
