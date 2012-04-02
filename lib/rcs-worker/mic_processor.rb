module RCS
module Worker

  class MicRecording

    attr_accessor :timecode, :duration, :sample_rate

    def initialize(evidence)
      @mic_id = evidence[:data][:mic_id]
      @sample_rate = evidence[:data][:sample_rate]
      @timecode = tc evidence
      @duration = 0
    end

    def accept?(evidence)
      @mic_id == evidence[:data][:mic_id] and @duration < 1800 # split every 30 minutes
    end

    def file_name
      @mic_id
    end

    def tc(evidence)
      evidence[:da]
    end

    def feed(evidence)

      @timecode = tc evidence

      left_pcm = Array.new evidence[:wav]
      right_pcm = Array.new evidence[:wav]

      @encoder ||= ::MP3Encoder.new(2, @sample_rate)
      unless @encoder.nil?
        @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
          File.open("#{file_name}.mp3", 'ab') {|f| f.write(mp3_bytes) }
        end
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
      @mic ||= MicRecording.new(evidence)
      unless @mic.accept? evidence
        puts "#{@mic.timecode} (#{@mic.timecode.to_f}) -> #{tc(evidence)} #{tc(evidence).to_f}"
        @mic = MicRecording.new(evidence)
      end

      @mic.feed(evidence)
      nil
    end
  end

end
end