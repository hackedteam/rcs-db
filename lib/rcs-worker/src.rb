require 'ffi'

module SRC
  extend FFI::Library
  extend RCS::Tracer

  class DATA < FFI::Struct
    layout :data_in, :float,            # pointer to input data samples
           :data_out, :float,           # pointer to output
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
	
    attach_function :src_simple, [:pointer, :int, :int], :int

    attach_function :src_new, [:int, :int, :pointer], :pointer
    attach_function :src_delete, [:pointer], :pointer

    attach_function :src_process, [:pointer, :pointer], :int
    attach_function :src_reset, [:pointer], :int
    attach_function :src_set_ratio, [:pointer, :double], :int

    attach_function :short_to_float, :src_short_to_float_array, [:pointer, :pointer, :int], :void
    attach_function :float_to_short, :src_float_to_short_array, [:pointer, :pointer, :int], :void

    attach_function :strerror, :src_strerror, [:int], :string
  rescue Exception => e
    trace :fatal, "ERROR: Cannot open libsamplerate"
    exit!
  end
end