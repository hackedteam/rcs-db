require_relative 'audio_processor'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

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
    
    info = RCS::EvidenceManager.instance_info @id
    trace :info, "Created processor for backdoor #{info['build']}:#{info['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{info['key']}"
    @key = Digest::MD5.digest info['key']

    @audio_processor = AudioProcessor.new
  end
  
  def resume
    @state = :running
    @seconds_sleeping = 0
  end
  
  def take_some_rest
    sleep 1
    @seconds_sleeping += 1
    trace :debug, "[#{Thread.current}][#{@id}] sleeping some [#{@seconds_sleeping}]."
  end
  
  def put_to_sleep
    @state = :stopped
    trace :debug, "[#{Thread.current}][#{@id}] sleeping too much, let's stop!"
  end
  
  def stopped?
    @state == :stopped
  end
  
  def sleeping_too_much?
    @seconds_sleeping >= SLEEP_TIME
  end
  
  def queue(evidence)
    @evidences << evidence unless evidence.nil?
    #trace :info, "queueing #{evidence} for #{@id}"
    
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
            
            case evidence.type
            when :CALL
              trace :debug, "Evidence channel #{evidence.channel} callee #{evidence.callee} with #{evidence.wav.size} bytes of data."
              @audio_processor.feed(evidence)
              #@audio_processor.to_wavfile
            end
            
            trace :debug, "[#{Thread.current}][#{@id}] processed #{evidence_id} of type #{evidence.type}, #{data.size} bytes."
            
          rescue EvidenceDeserializeError => e
            trace :info, "DECODING FAILED: " << e.to_s
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