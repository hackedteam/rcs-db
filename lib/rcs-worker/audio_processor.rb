module RCS
module Worker

require 'ffi'
require 'rcs-common/trace'
require 'rcs-worker/speex'
require 'rcs-worker/wave'
require 'rcs-worker/src'

require 'digest/md5'

class AudioProcessingError < StandardError
  attr_reader :msg
  def initialize(msg)
    @msg = msg
  end

  def to_s
    @msg
  end
end

class Channel
  include Tracer
  attr_reader :sample_rate, :start_time, :stop_time, :wav_data, :status
  
  def initialize(evidence)
    @name = evidence.channel.to_s
    @sample_rate = evidence.sample_rate
    @start_time = evidence.start_time
    @stop_time = @start_time
    @wav_data = String.new
    @status = :open
    trace :debug, "creating new channel #{self.id}."
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time.to_f}:#{@stop_time.to_f}:#{@status.to_s}"
  end
  
  def self.other_than channel
    channel == :incoming ? :outgoing : :incoming
  end
  
  def close!
    @status = :closed
    trace :debug, "Closing channel #{self.id}"
  end
  
  def closed?
    @status == :closed
  end
  
  def fill(gap)
    samples_to_fill = @sample_rate * gap
    #trace :debug, "filling #{samples_to_fill} samples to fill #{gap} seconds of missing data."
    data = StringIO.new
    data.write([0].pack("S") * samples_to_fill.ceil)
    @wav_data += data.string
  end
  
  def time_gap(evidence)
    evidence.start_time.to_f - @stop_time.to_f
  end
  
  def accept?(evidence)
    return false if closed?
    gap = time_gap evidence
    return false if gap >= 5.0
    return true
  end
  
  def feed(evidence)
    trace :debug, "Evidence channel #{evidence.channel} callee #{evidence.callee} with #{evidence.wav.size} bytes of data."
    
    if evidence.end_call?
      self.close!
      return
    end
    
    gap = time_gap(evidence)
    fill gap unless gap == 0
    
    @stop_time = evidence.stop_time
    @wav_data += evidence.wav
    
    #to_wavfile
  end
  
  def bytes
    @wav_data.size
  end
  
  def num_samples
    bytes.to_f / 16
  end
  
  def seconds
    num_samples.to_f / @sample_rate
  end
  
  def to_s
    self.id
  end
  
  def to_float_samples
    @wav_data.unpack('F*').spack('S*')
  end
  
  def to_wavfile (filename = '')
    name = "#{Digest::MD5.hexdigest("#{self.id}")}_#{@name}.wav"
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
  include Tracer
  attr_writer :start_time
  
  # status of call can be:
  #   - :queueing only first channel is present, queue data, maintain speex
  #   - :fillin   second channel arrived, fill in later channel with silence
  #   - :resampling second channel arrived, filled in, resample data as they arrive
  
  def initialize(evidence)
    @callee = evidence.callee
    @start_time = evidence.start_time
    @status = :queueing
    @channels = {}
    @resampled = :not_yet
    create_channel evidence
    trace :info, "new call for #{@callee} #{@start_time} on channel #{evidence.channel.to_s.upcase}"
  end
  
  def id
    "#{@callee}:#{@start_time.to_f}"
  end
  
  def queueing?
    @channels.size < 2
  end
  
  def is_fillin?
    @status == :fillin
  end
  
  def accept?(evidence)
    # we accept evidence only if relative channel accept it
    channel = get_channel evidence
    return channel.accept? evidence unless channel.nil?
    trace :debug, "evidence is not being accepted by call #{id}"
    return false
  end
  
  def get_channel(evidence)
    return @channels[evidence.channel] || create_channel(evidence)
  end
  
  def create_channel(evidence)
    channel = Channel.new evidence
    @channels[evidence.channel] = channel
    
    # fix start time
    @start_time = get_start_time
    
    return channel
  end
  
  def closed?
    closed_channels = @channels.select {|k,v| v.closed? unless v.nil? }
    return closed_channels.size == @channels.size
  end
  
  def feed(evidence)
    # if evidence is empty or call is closed, refuse feeding
    return false if evidence.wav.size == 0
    return false if closed?
    
    # get the correct channel for the evidence
    channel = get_channel(evidence)
    trace :debug, "feeding #{evidence.wav.size} bytes at #{evidence.start_time}:#{evidence.stop_time} to #{channel.id}"
    
    # check if channel accepts evidence
    unless channel.accept? evidence
      trace :debug, "channel refused evidence"
      return false
    end
    
    channel.feed evidence

    # update status
    update_status
    
    return true
  end
  
  def sample_rates
    @channels.values.collect {|c| c.sample_rate}
  end
  
  def min_sample_rate
    sample_rates.sort.first
  end
  
  def update_status
    if @channels.size < 2
      @status == :queueing
      return
    else # we have (at least) two channels
      @status == :fillin
      trace :debug, "Lesser sample rate: #{min_sample_rate}, will be used for resampling."
    end
  end

  def to_s
    string = "---\nCALL #{self.id}\n"
    @channels.each {|k, c| string += "\t- #{k} #{c.seconds} #{c.num_samples}\n" }
    string += "---\n"
    return string
  end
  
  def to_wavfile
    @channels.keys.each do |k|
      @channels[k].to_wavfile "#{self.object_id}_#{k.to_s}.wav"
    end
  end
  
  def get_start_time
    times = @channels.values.collect {|c| c.start_time.to_f }
    times.min
  end
  
  def to_resampled_stream
    #return nil unless @channels.size == 2
    
    # sort channels by start time
    sorted_channels = @channels.values.sort_by {|c| c.start_time}
    
    #second is
    
    desired_sample_rate = 8000
    src_data = SRC::DATA.new
    channel = sorted_channels.first
    float_samples = channel.to_float_samples
    
    bytecount = float_samples.size
    in_pointer = FFI::MemoryPointer.new(:float, float_samples.size)
    
    in_pointer.put_bytes(0, float_samples, 0, float_samples.size)
    src_data[:data_in] = in_pointer
    src_data[:input_frames] = channel.num_samples
    
    out_pointer = FFI::MemoryPointer.new(:float, channel.num_samples)
    src_data[:data_out] = out_pointer
    src_data[:output_frames] = channel.num_samples
    
    src_data[:ratio] = channel.sample_rate / desired_sample_rate
    
    SRC::simple(src_data, SRC::BEST_QUALITY, 1)
    
    wav_data = out_pointer.get_bytes(src_data[:output_frames_gen] * 4).unpack('F*').pack('S*')
    
    name = "#{Digest::MD5.hexdigest("#{self.id}")}_#{channel.name}_resampled.wav"
    File.open(name, 'wb') do |f|
      data_header = Wave.data_header wav_data.size
      chunk_header = Wave.chunk_header 1, desired_sample_rate
      main_header = Wave.main_header wav_data.size + data_header.size + chunk_header.size
      f.write main_header
      f.write chunk_header
      f.write data_header
      f.write wav_data
    end
  end
end

class AudioProcessor
  include Tracer
  require 'pp'
  
  def initialize
    @calls = []
  end
  
  def get_call(evidence)
    open_calls = @calls.select {|c| c.accept? evidence and not c.closed? }
    return open_calls.first unless open_calls.empty?

    # no valid call was found, we need to create a new one
    call = create_call(evidence)
    return call
  end
  
  def create_call(evidence)
    call = Call.new evidence
    @calls << call
    trace :debug, "issuing a new call for #{evidence.callee}:#{evidence.start_time}"
    call
  end
  
  def feed(evidence)
    return
    
    # if callee is unknown or evidence is empty, evidence is invalid, ignore it
    return if evidence.callee.size == 0 or evidence.wav.size == 0
    
    call = get_call evidence
    call.feed evidence unless call.nil?
  end
  
  def to_s
    string = ''
    @calls.each do |c|
      string += "#{c}\n"
    end
    return string
  end
  
  def to_wavfile
    @calls.each do |c|
      c.to_wavfile
      #c.to_resampled_stream
    end
  end
end

end # Audio::
end # RCS::
