require 'ffi'
require 'stringio'
require 'rbconfig'

require 'rcs-common/trace'

module MP3Lame
  include RCS::Tracer
  extend FFI::Library

  base_path = File.dirname(__FILE__)
  case RbConfig::CONFIG['host_os']
    when /darwin/
  	  ffi_lib File.join(base_path, 'libs/lame/macos/libmp3lame.0.dylib')
    when /mingw/
  		ffi_lib File.join(base_path, 'libs/lame/win/libmp3lame.dll')
  end
  
  ffi_convention :stdcall
  
  class Report < FFI::Struct
    layout :msgf, :pointer,
           :debugf, :pointer,
           :errorf, :pointer
  end
  
  class AsmOptimizations < FFI::Struct
    layout :mmx, :int,
           :amd3dnow, :int,
           :sse, :int
  end
  
  class LameGlobalFlags < FFI::Struct
    layout :class_id, :uint,
           :num_samples, :ulong,
           :num_channels, :int,
           :in_samplerate, :int,
           :out_samplerate, :int,
           :scale, :float,
           :scale_left, :float,
           :scale_right, :float,
           :analysis, :int,
           :bWriteVbrTag, :int,
           :decode_only, :int,
           :quality, :int,
           :mode, :int,
           :force_ms, :int,
           :free_format, :int,
           :findReplayGain, :int,
           :decode_on_the_fly, :int,
           :write_id3tag_automatic, :int,
           :brate, :int,
           :compression_ratio, :float,
           :copyright, :int,
           :original, :int,
           :extension, :int,
           :emphasis, :int,
           :error_protection, :int,
           :strict_ISO, :int,
           :disable_reservoir, :int,
           :quant_comp, :int,
           :quant_comp_short, :int,
           :experimentalY, :int,
           :experimentalZ, :int,
           :exp_nspsytune, :int,
           :preset, :int,
           :VBR, :int,
           :VBR_q_frac, :int,
           :VBR_q, :int,
           :VBR_mean_bitrate_kbps, :int,
           :VBR_min_bitrate_kbps, :int,
           :VBR_max_bitrate_kbps, :int,
           :VBR_hard_min, :int,
           :lowpassfreq, :int,
           :highpassfreq, :int,
           :lowpasswidth, :int,
           :highpasswidth, :int,
           :maskingadjust, :float,
           :maskingadjust_short, :float,
           :ATHonly, :int,
           :ATHshort, :int,
           :noATH, :int,
           :ATHtype, :int,
           :ATHcurve, :float,
           :ATHlower, :float,
           :athaa_type, :int,
           :athaa_loudapprox, :int,
           :athaa_sensitivity, :int,
           :short_blocks, :int,
           :useTemporal, :int,
           :interChRatio, :float,
           :msfix, :float,
           :tune, :int,
           :tune_value_a, :float,
           :report, Report,
           :version, :int,
           :encoder_delay, :int,
           :encoder_padding, :int,
           :framesize, :int,
           :frameNum, :int,
           :lame_allocated_gfp, :int,
           :internal_flags, :pointer,
           :asm_optimizations, AsmOptimizations 
  end
  
  JOINT_STEREO = 1

  attach_function :get_lame_version, [], :string

  attach_function :lame_init, [], :pointer
  attach_function :lame_set_num_channels, [:pointer, :int], :void
  attach_function :lame_set_in_samplerate, [:pointer, :int], :void
  attach_function :lame_set_brate, [:pointer, :int], :void
  attach_function :lame_set_mode, [:pointer, :int], :void
  attach_function :lame_set_quality, [:pointer, :int], :void
  attach_function :lame_set_VBR_q, [:pointer, :int], :void
  attach_function :lame_set_VBR_min_bitrate_kbps, [:pointer, :int], :void
  attach_function :lame_set_VBR_max_bitrate_kbps, [:pointer, :int], :void
  
  attach_function :lame_init_params, [:pointer], :int
  attach_function :lame_encode_buffer, [:pointer, :pointer, :pointer, :int, :pointer, :int], :int
  attach_function :lame_encode_buffer_float, [:pointer, :pointer, :pointer, :int, :pointer, :int], :int
  attach_function :lame_encode_flush, [:pointer , :pointer, :int], :int
end

class MP3Encoder
  include RCS::Tracer

  def initialize(n_channels, sample_rate)
    @n_channels = n_channels
    @sample_rate = sample_rate
    
    @mp3lame = MP3Lame::lame_init
    @buffer = nil
    
    gfp = MP3Lame::LameGlobalFlags.new(@mp3lame)
    MP3Lame::lame_set_num_channels(@mp3lame, @n_channels)
    MP3Lame::lame_set_in_samplerate(@mp3lame, @sample_rate)
   
    MP3Lame::lame_set_mode( @mp3lame, MP3Lame::JOINT_STEREO )
    MP3Lame::lame_set_quality( @mp3lame, 5 )
    MP3Lame::lame_set_brate( @mp3lame, 128 )
    MP3Lame::lame_set_VBR_q( @mp3lame, 4 )
    MP3Lame::lame_set_VBR_min_bitrate_kbps( @mp3lame, 96 )
    MP3Lame::lame_set_VBR_max_bitrate_kbps( @mp3lame, 160 );
    
    return true if MP3Lame::lame_init_params(@mp3lame) >= 0
    return nil
  end

  def feed(left, right)
    num_samples = [left.size, right.size].min
    buffer_size = (1.25 * num_samples + 7200).ceil
    
    buffer = FFI::MemoryPointer.new(:float, buffer_size)

    left_pcm = left.pack 'F*'
    right_pcm = right.pack 'F*'

    mp3_bytes = MP3Lame::lame_encode_buffer_float(@mp3lame, left_pcm, right_pcm, num_samples, buffer, buffer_size)
    yield buffer.read_bytes(mp3_bytes)
  end

  def flush
    mp3_bytes = MP3Lame::lame_encode_flush(@mp3lame, buffer, buffer_size)
    yield buffer.read_bytes(mp3_bytes)
  end
end
