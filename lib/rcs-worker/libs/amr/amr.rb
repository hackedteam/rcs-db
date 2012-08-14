require 'ffi'
require 'stringio'
require 'bson'
require 'rbconfig'

require 'rcs-common/trace'

require_relative '../SRC/src'
require_relative 'wave'

module AMR
  extend RCS::Tracer
  extend FFI::Library

  base_path = File.dirname(__FILE__)
  case RbConfig::CONFIG['host_os']
    when /darwin/
  	  ffi_lib File.join(base_path, 'macos/libopencore-amrnb.0.dylib')
    when /mingw/
  		ffi_lib File.join(base_path, 'win/libopencore-amrnb-0.dll')
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

      chunk = stream.read(1)
      mode = chunk.unpack('C').shift
      size = AMR::SIZES[(mode >> 3) & 0x0f]

      #trace :debug, "[AMR] size: #{size}"

      data = stream.read size
      break if data.nil? # Symbian may save invalid chunks ...
      chunk += data

      buffer = FFI::MemoryPointer.new :char, chunk.size
      buffer.put_bytes 0, chunk, 0, chunk.size

      AMR::decode amr, buffer, output_short, 0

      #trace :debug, "[AMR] decode"

      short_samples = output_short.read_bytes AMR_FRAME_SIZE * 2
      wav_ary.concat short_samples.unpack('s*').pack('f*').unpack('f*')

      #wav = Wave.new 1, 8000
      #wav.write "#{BSON::ObjectId.new.to_s}.wav", wav_ary
      #SRC::short_to_float output_short, output_float, AMR_FRAME_SIZE
      #wav_ary.concat output_float.read_array_of_float(AMR_FRAME_SIZE)

      #trace :debug, "[AMR] frames: #{wav_ary.size}"
    end
    AMR::exit amr

    wav_ary
  end
end
