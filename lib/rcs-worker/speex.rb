
require 'rcs-common/trace'

require 'ffi'

module Speex
	extend FFI::Library
  extend RCS::Tracer

	class SpeexMode < FFI::Struct
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
	
	class SpeexBits < FFI::Struct
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
  
  begin
	  ffi_lib 'speex'
    ffi_convention :stdcall

    attach_function :decoder_init, :speex_decoder_init, [:pointer], :pointer
    attach_function :decoder_destroy, :speex_decoder_destroy, [:pointer], :void
    attach_function :decoder_ctl, :speex_decoder_ctl, [:pointer, :int, :pointer], :int
    attach_function :decode, :speex_decode, [:pointer, :pointer, :pointer], :int

	  attach_function :bits_init, :speex_bits_init, [:pointer], :void
    attach_function :bits_destroy, :speex_bits_destroy, [:pointer], :void
    attach_function :bits_read_from, :speex_bits_read_from, [:pointer, :pointer, :int], :void

    attach_function :lib_get_mode, :speex_lib_get_mode, [:int], :pointer
  rescue Exception => e
    trace :fatal, "ERROR: Cannot open libspeex"
  end
  
end

=begin

encoder = Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_NB))

enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
Speex.decoder_ctl(encoder, Speex::SET_ENH, enhancement_ptr);
framesize_ptr = FFI::MemoryPointer.new(:int32).write_uint 0 
Speex.decoder_ctl(encoder, Speex::GET_FRAME_SIZE, framesize_ptr);
puts framesize_ptr.get_uint 0

bits_ptr = FFI::MemoryPointer.new :pointer
bits = Speex::SpeexBits.new(bits_ptr)
Speex.bits_init(bits.pointer)
Speex.bits_destroy(bits.pointer)

=end