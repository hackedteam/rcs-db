require 'ffi'

module SRC
  extend FFI::Library

  class DATA < FFI::Struct
    layout :data_in, :pointer,            # pointer to input data samples
           :data_out, :pointer,           # pointer to output
           :input_frames, :long,        # number of frames of input
           :output_frames, :long,       # number of frames generated
           :input_frames_used, :long,
           :output_frames_gen, :long,
           :end_of_input, :int,
           :ratio, :double          # equal to input_sample_rate / output_sample_rate
  end
  
  SINC_BEST_QUALITY = 0
  SINC_MEDIUM_QUALITY = 1
  SINC_FASTEST = 2
  ZERO_ORDER_HOLD = 3
  LINEAR = 4
  
  begin
	  base_path = File.dirname(__FILE__)
	  case RUBY_PLATFORM
        when /darwin/
			ffi_lib File.join(base_path, 'libs/SRC/macos/libsamplerate.0.dylib')
        when /mingw/
			ffi_lib File.join(base_path, 'libs/SRC/win/libsamplerate.dll')
	  end
	  
    attach_function :simple, :src_simple, [:pointer, :int, :int], :int
    
    attach_function :new, :src_new, [:int, :int, :pointer], :pointer
    attach_function :delete, :src_delete, [:pointer], :pointer
    
    attach_function :process, :src_process, [:pointer, :pointer], :int
    attach_function :reset, :src_reset, [:pointer], :int
    attach_function :set_ratio, :src_set_ratio, [:pointer, :double], :int

    attach_function :short_to_float, :src_short_to_float_array, [:pointer, :pointer, :int], :void
    attach_function :float_to_short, :src_float_to_short_array, [:pointer, :pointer, :int], :void
    
    attach_function :strerror, :src_strerror, [:int], :string
  rescue Exception => e
    trace :fatal, "ERROR: Cannot open libsamplerate #{e.message}"
    exit!
  end

  class Resampler
    def initialize(to_sample_rate)
      @to_sample_rate = to_sample_rate
    end

    def resample_channel(wav_ary, sample_rate, is_short = false)
      errorptr = FFI::MemoryPointer.new :pointer
      src_state = SRC::new SRC::SINC_FASTEST, 1, errorptr # resample a single channel

      src_data_ptr = FFI::MemoryPointer.new SRC::DATA.size, 1, false
      src_data = SRC::DATA.new src_data_ptr
      src_data[:ratio] = @to_sample_rate * 1.0 / sample_rate

      #trace :debug, "Encoding #{wav_ary.size * FFI::type_size(:float)} bytes => #{wav_ary.size} wave frames [ratio #{src_data[:ratio]}]."

      src_data[:end_of_input] = 0
      src_data[:input_frames] = 0
      src_data[:output_frames] =  wav_ary.size

      in_ptr = FFI::MemoryPointer.new :float, wav_ary.size
      src_data[:data_in] = in_ptr

      out_ptr = FFI::MemoryPointer.new :float, wav_ary.size
      src_data[:data_out] = out_ptr

      if is_short
        short_samples = FFI::MemoryPointer.new :short, wav_ary.size
        resampled_short_samples = FFI::MemoryPointer.new :short, wav_ary.size
      end

      resampled_frames = []
      until src_data[:end_of_input] == 1 and src_data[:output_frames_gen] == 0

        if src_data[:input_frames] == 0
          if is_short
            short_samples.write_bytes wav_ary.pack('s*'), 0, wav_ary.size * FFI::type_size(:short)
            SRC::short_to_float short_samples, src_data[:data_in], wav_ary.size
          else
            src_data[:data_in].put_array_of_float32 0, wav_ary
          end
          src_data[:input_frames] =  wav_ary.size
          src_data[:end_of_input] = 1
        end

        # process data
        error = SRC::process src_state, src_data.pointer

        # convert generated frames and store them
        unless src_data[:output_frames_gen] == 0
          if is_short
            SRC::float_to_short src_data[:data_out], resampled_short_samples, src_data[:output_frames_gen]
            resampled_frames.concat resampled_short_samples.read_bytes(src_data[:output_frames_gen] * 2).unpack('s*')
          else
            resampled_frames.concat src_data[:data_out].read_array_of_float(src_data[:output_frames_gen])
          end
        end

        src_data[:input_frames] -= src_data[:input_frames_used]
        src_data[:data_in] += src_data[:input_frames_used] if src_data[:input_frames] > 0

        #trace :debug, "Generated #{src_data[:output_frames_gen]} frames, used #{src_data[:input_frames_used]}, still #{src_data[:input_frames]} in input."
      end
      return resampled_frames
    end

  end

end # SRC

