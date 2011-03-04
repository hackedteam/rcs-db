module RCS

require 'rcs-worker/speex'

module CallPostProcessing
  
  def postprocess
    
    raw_content = StringIO.new @content
    speex_chunks = []
    while raw_content.eof? == false do
      len = raw_content.read(4).unpack("I").shift
      chunk = raw_content.read(len)
      speex_chunks << chunk unless chunk.nil?
    end
    
    decoder = Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_UWB))
    
    # enable enhancement
    enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
    Speex.decoder_ctl(decoder, Speex::SET_ENH, enhancement_ptr);
    
    # get frame size
    frame_size_ptr = FFI::MemoryPointer.new(:int32).write_uint 0
    Speex.decoder_ctl(decoder, Speex::GET_FRAME_SIZE, frame_size_ptr);
    frame_size = frame_size_ptr.get_uint(0)
    
    bits = Speex::Bits.new
    Speex.bits_init(bits.pointer)
    
    @wav = ''
    speex_chunks.each do |c|
      Speex.bits_read_from(bits.pointer, FFI::MemoryPointer.from_string(c), c.size)
      output_buffer = FFI::MemoryPointer.new(:float, frame_size)
      Speex.decode(decoder, bits.pointer, output_buffer)
      @wav += output_buffer.get_string(frame_size)
    end
    
    puts "Decoded #{@wav.length} bytes of WAV data."
    
    Speex.bits_destroy(bits.pointer)
    Speex.decoder_destroy(decoder)
    
  end
  
end

end # RCS::
