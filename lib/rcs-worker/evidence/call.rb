module RCS

require 'rcs-worker/speex'
require 'rcs-worker/audio_processor'

module CallProcessing
  
  attr_reader :wav
  
  def process
    
    decoder = Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_UWB))
    
    # enable enhancement
    enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
    Speex.decoder_ctl(decoder, Speex::SET_ENH, enhancement_ptr);
    
    # get frame size
    frame_size_ptr = FFI::MemoryPointer.new(:int32).write_uint 0
    Speex.decoder_ctl(decoder, Speex::GET_FRAME_SIZE, frame_size_ptr);
    frame_size = frame_size_ptr.get_uint(0)
        
    raw_content = StringIO.new @info[:content]
    wave_buffer = ''
    
    bits = Speex::Bits.new
    Speex.bits_init(bits.pointer)
    
    while not raw_content.eof? do
      len = raw_content.read(4).unpack("L").shift
      chunk = raw_content.read(len)
      unless chunk.nil?
        buffer = FFI::MemoryPointer.new(:char, chunk.size)
        buffer.put_bytes(0, chunk, 0, chunk.size)
        
        Speex.bits_read_from(bits.pointer, buffer, buffer.size)
        
        output_buffer = FFI::MemoryPointer.new(:float, frame_size)
        Speex.decode(decoder, bits.pointer, output_buffer)
        
        # Speex outputs 32 bits float samples, wave needs 16 bit integers
        wave_buffer += output_buffer.get_bytes(0, frame_size*4).unpack('F*').pack('S*')
      end
    end
    
    Speex.bits_destroy(bits.pointer)
    Speex.decoder_destroy(decoder)
    
    @wav = wave_buffer
    
  end
  
end

end # RCS::
