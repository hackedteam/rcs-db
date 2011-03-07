module RCS
module Worker

require 'ffi'
require 'rcs-common/trace'
require 'rcs-worker/speex'
require 'rcs-worker/wave'

require 'digest/md5'

class Channel
  attr_reader :sample_rate, :start_time, :wav_data
  
  def initialize(sample_rate, start_time)
    @sample_rate = sample_rate
    @start_time = start_time
    @wav_data = String.new
  end
  
  def feed(wav_data)
    @wav_data += wav_data
  end
  
  def size
    @wav_data.size
  end
  
  def to_s
    "#{size} bytes, samplerate #{@sample_rate}"
  end
  
  def to_wavfile (filename = '')
    name = "#{Digest::MD5.hexdigest("#{@start_time}")}.wav"
    File.open(name, 'wb') do |f|
      data_header = Wave.data_header @wav_data.size
      chunk_header = Wave.chunk_header 1, @sample_rate
      main_header = Wave.main_header @wav_data.size + data_header.size + chunk_header.size
      f.write main_header
      f.write chunk_header
      f.write data_header
      f.write @wav_data
    end
  end
end

class Call
  attr_writer :start_time
  attr_reader :incoming, :outgoing
  
  def initialize(start_time)
    @start_time = start_time
    @channels = {}
  end
  
  def append_to_channel(evidence)
    @channels[evidence.channel] = Channel.new(evidence.sample_rate, evidence.start_time) unless @channels.has_key? evidence.channel
    @channels[evidence.channel].feed(evidence.wav)
    puts "[#{object_id}] feeding #{evidence.wav.size} bytes at #{evidence.start_time}:#{evidence.stop_time}"
  end
  
  def to_s
    string = ''
    @channels.keys.each do |c|
      string += "#{c} #{@channels[c]} "
    end
    return string
  end
  
  def to_wavfile
    @channels.each do |k, c|
      c.to_wavfile "#{self.object_id}_#{k.to_s}.wav"
    end
  end
end

class AudioProcessor
  include Tracer
  require 'pp'
  
  def initialize
    @calls = {}
  end
  
  def feed(evidence)
    
    if evidence.callee.size == 0
      trace :debug, "ignoring sample, no calling info ..."
      return
    end
    
    # check if a new call is beginning
    call_id = evidence.callee
    if @calls.has_key?(call_id)
      call = @calls[call_id]
    else
      trace :debug, "issuing a new call for #{call_id}, starting time #{evidence.start_time}"
      call = Call.new(evidence.start_time)
      @calls[call_id] = call
    end
    
    # add sample to correct channel of call
    
    call.append_to_channel evidence
  end

  def to_s
    string = ''
    @calls.keys.each do |c|
      string += "#{c} #{@calls[c]}\n"
    end
    return string
  end

  def to_wavfile
    @calls.keys.each do |c|
      @calls[c].to_wavfile
    end
  end

=begin
  def to_s
    @calls.keys.each do |k|
      trace :debug, "call #{k}"
      @calls[k].keys.each do |c|
        bytes = 0
        @calls[k][c].each do |s|
          trace :debug, "\t\t#{s.start_time.usec}:#{s.stop_time.usec}"
          bytes += s.content.size
          decode_speex(s.content)
        end
        trace :debug, "\t- #{c} #{bytes}"
      end
    end
  end
=end
  
end

end # Audio::
end # RCS::
