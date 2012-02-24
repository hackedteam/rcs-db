require 'ffi'

module MP3Lame
  extend FFI::Library
  base_path = File.dirname(__FILE__)
  case RUBY_PLATFORM
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

  attach_function :get_lame_version, [], :string

  attach_function :lame_init, [], :pointer
  attach_function :lame_set_num_channels, [:pointer, :int], :void
  attach_function :lame_set_in_samplerate, [:pointer, :int], :void
  attach_function :lame_set_brate, [:pointer, :int], :void
  attach_function :lame_set_mode, [:pointer, :int], :void
  attach_function :lame_set_quality, [:pointer, :int], :void
  
  attach_function :lame_init_params, [:pointer], :int
  attach_function :lame_encode_buffer, [:pointer, :pointer, :pointer, :int, :pointer, :int], :int
  attach_function :lame_encode_flush, [:pointer , :pointer, :int], :int
end

puts "FFI interface to libmp3lame #{MP3Lame::get_lame_version}"

require 'wav-file'
f = open("/Users/daniele/Desktop/wave/canzone.wav")
format = WavFile::readFormat(f)
dataChunk = WavFile::readDataChunk(f)
puts format

objptr = MP3Lame::lame_init
gfp = MP3Lame::LameGlobalFlags.new(objptr)
MP3Lame::lame_set_num_channels(objptr, format.channel)
MP3Lame::lame_set_in_samplerate(objptr, format.hz)
MP3Lame::lame_set_brate(objptr, 128)
MP3Lame::lame_set_mode(objptr,1);
MP3Lame::lame_set_quality(objptr,2);
puts gfp[:num_channels]
puts gfp[:in_samplerate]
puts gfp[:mode]
puts gfp[:quality]
puts gfp[:brate]

if MP3Lame::lame_init_params(objptr) >= 0
  puts "params set!"
else
  puts "something wrong in params..."
end

bit = 's*' if format.bitPerSample == 16 # int16_t
bit = 'c*' if format.bitPerSample == 8 # signed char
wavs = dataChunk.data.unpack(bit) # read binary

num_samples = wavs.size
mp3buffer_size = 1.25 * num_samples + 7200
puts "Required buffer size #{mp3buffer_size}"

mp3buffer = FFI::MemoryPointer.new(:char, mp3buffer_size)
puts mp3buffer.class

class Array
  def odd_values
    (0...length / 2).collect { |i| self[i*2 + 1] }
  end

  def even_values
    (0...(length + 1) / 2).collect { |i| self[i*2] }
  end
end

right_pcm = wavs.even_values
left_pcm = wavs.odd_values

loop do
  lpcm = left_pcm.shift(10).pack 's*'
  rpcm = right_pcm.shift(10).pack 's*'

  break if left_pcm.size == 0

  mp3_bytes = MP3Lame::lame_encode_buffer(objptr, lpcm, rpcm, 10, mp3buffer, mp3buffer_size)

  File.open('canzone.mp3', 'a') {|f| f.write(mp3buffer.read_string(mp3_bytes)) }
end

mp3_bytes = MP3Lame::lame_encode_flush(objptr, mp3buffer, mp3buffer_size)
File.open('canzone.mp3', 'a') {|f| f.write(mp3buffer.read_string(mp3_bytes)) }
