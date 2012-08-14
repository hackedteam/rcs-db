
require 'rcs-common/trace'

require 'ffi'
require 'rbconfig'

module Speex
	extend FFI::Library
  extend RCS::Tracer

	class Mode < FFI::Struct
	  layout :mode,       :pointer,
	         :query,      :pointer,
	         :modeName,   :string,
	         :modeID,     :int,
	         :bistream_version, :int,
	         :enc_init,   :pointer,
	         :enc_destroy,:pointer,
	         :enc,        :pointer,
	         :dec_init,   :pointer,
	         :dec_destroy,:pointer,
	         :dec,        :pointer,
	         :enc_ctl,    :pointer,
	         :dec_ctl,    :pointer
  end
	
	class Bits < FFI::Struct
	  layout :chars,      :string,
	         :nbBits,     :int,
	         :charPtr,    :int,
	         :bitPtr,     :int, 
	         :owner,      :int,
	         :overflow,   :int,
	         :buf_size,   :int,
	         :reserved1,  :int,
	         :reserved2,  :int
  end
  
  MODEID_NB = 0
  MODEID_UWB = 2
  SET_ENH = 0
  GET_FRAME_SIZE = 3
  GET_VERSION_STRING = 9
  
  begin
    base_path = File.dirname(__FILE__)
	case RbConfig::CONFIG['host_os']
        when /darwin/
			ffi_lib File.join(base_path, 'macos/libspeex.1.5.0.dylib')
        when /mingw/
			ffi_lib File.join(base_path, 'win/libspeex.dll')
	end
    
	ffi_convention :stdcall

    attach_function :decoder_init, :speex_decoder_init, [:pointer], :pointer
    attach_function :decoder_destroy, :speex_decoder_destroy, [:pointer], :void
    attach_function :decoder_ctl, :speex_decoder_ctl, [:pointer, :int, :pointer], :int
    attach_function :decode, :speex_decode, [:pointer, :pointer, :pointer], :int

	  attach_function :bits_init, :speex_bits_init, [:pointer], :void
    attach_function :bits_init_buffer, :speex_bits_init_buffer, [:pointer, :pointer, :int], :void
    attach_function :bits_destroy, :speex_bits_destroy, [:pointer], :void
    attach_function :bits_read_from, :speex_bits_read_from, [:pointer, :pointer, :int], :void

    attach_function :lib_get_mode, :speex_lib_get_mode, [:int], :pointer
    attach_function :lib_ctl, :speex_lib_ctl, [:int, :pointer], :int
  rescue Exception => e
    trace :fatal, "ERROR: Cannot open libspeex"
    exit!
  end

  def self.get_wav_frames(data, mode)

    decoder = Speex.decoder_init(Speex.lib_get_mode(mode))

    # enable enhancement
    enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
    Speex.decoder_ctl(decoder, Speex::SET_ENH, enhancement_ptr)

    # get frame size
    frame_size_ptr = FFI::MemoryPointer.new(:int32).write_uint 0
    Speex.decoder_ctl(decoder, Speex::GET_FRAME_SIZE, frame_size_ptr)
    frame_size = frame_size_ptr.get_uint(0)

    bits = Speex::Bits.new
    Speex.bits_init(bits.pointer)

    wav_ary = []
    stream = StringIO.new data
    while not stream.eof? do
      # read one chunk
      len = stream.read(4).unpack("L").shift
      chunk = stream.read(len)
      break if chunk.nil?

      if chunk.size == len
        buffer = FFI::MemoryPointer.new(:char, len)
        buffer.put_bytes(0, chunk, 0, len)

        Speex.bits_read_from(bits.pointer, buffer, len)

        output_buffer = FFI::MemoryPointer.new(:float, frame_size)
        Speex.decode(decoder, bits.pointer, output_buffer)

        # Speex outputs 32 bits float samples
        wav_ary.concat output_buffer.read_array_of_float(frame_size)
      end
    end

    Speex.bits_destroy(bits.pointer)
    Speex.decoder_destroy(decoder)

    wav_ary
  end

  def self.version
    ptr = FFI::MemoryPointer.new :pointer, 1
    Speex::lib_ctl Speex::GET_VERSION_STRING, ptr
    ptr.read_pointer.read_string
  end
end
