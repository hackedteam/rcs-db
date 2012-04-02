require 'ffi'
require 'stringio'

require_relative 'src'

module AMR
  extend FFI::Library

  base_path = File.dirname(__FILE__)
  case RUBY_PLATFORM
    when /darwin/
  	  ffi_lib File.join(base_path, 'libs/amr/macos/libopencore-amrnb.0.dylib')
    when /mingw/
  		ffi_lib File.join(base_path, 'libs/amr/win/libopencore-amrnb-0.dll')
  end

  AMR_FRAME_SIZE = 160
  SIZES = [12, 13, 15, 17, 19, 20, 26, 31, 5, 6, 5, 5, 0, 0, 0, 0]
  
  ffi_convention :stdcall

  attach_function :init, :Decoder_Interface_init, [], :pointer
  attach_function :exit, :Decoder_Interface_exit, [:pointer], :void
  attach_function :decode, :Decoder_Interface_Decode, [:pointer, :pointer, :pointer, :int], :void

  def self.get_wav_frames(data)

    stream = StringIO.new data

    prefix = stream.read(6)
    stream.rewind unless prefix.eql? "#!AMR\n"

    wav_ary = []
    amr = AMR::init
    until stream.eof?
      mode = stream.read 1
      size = AMR::SIZES[(mode.to_i >> 3) & 0x0f]

      buffer = stream.read size
      output = FFI::MemoryPointer.new :short, AMR_FRAME_SIZE

      AMR::decode amr, buffer, output, 0

      out_ptr = FFI::MemoryPointer.new :float, AMR_FRAME_SIZE
      SRC::short_to_float out_ptr, output, AMR_FRAME_SIZE

      wav_ary.concat out_ptr.read_array_of_float(AMR_FRAME_SIZE)
    end
    AMR::exit amr

    wav_ary
  end
end
