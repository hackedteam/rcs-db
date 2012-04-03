require 'ffi'
require 'stringio'

require 'rcs-common/trace'

require_relative 'src'

module AMR
  extend RCS::Tracer
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

    output_short = FFI::MemoryPointer.new :short, AMR_FRAME_SIZE
    output_float = FFI::MemoryPointer.new :float, AMR_FRAME_SIZE

    wav_ary = []
    amr = AMR::init
    until stream.eof?
      #trace :debug, "[AMR] stream pos: #{stream.pos}"

      mode = stream.read 1
      size = AMR::SIZES[(mode.to_i >> 3) & 0x0f]

      #trace :debug, "[AMR] size: #{size}"

      chunk = stream.read size
      break if chunk.nil?

      buffer = FFI::MemoryPointer.new :char, chunk.size
      buffer.write_bytes chunk, 0, chunk.size

      AMR::decode amr, buffer, output_short, 0

      #trace :debug, "[AMR] decode"

      SRC::short_to_float output_short, output_float, AMR_FRAME_SIZE

      wav_ary.concat output_float.read_array_of_float(AMR_FRAME_SIZE)

      #trace :debug, "[AMR] frames: #{wav_ary.size}"
    end
    AMR::exit amr

    wav_ary
  end
end
