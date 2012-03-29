module RCS

require_relative '../speex'
require_relative '../call_processor'
require_relative 'audio_evidence'

module CallProcessing
  extend AudioEvidence

  attr_reader :wav

  def end_call?
    self[:data][:grid_content].bytesize == 4 and self[:data][:grid_content] == "\xff\xff\xff\xff"
  end

  def process
    self[:wav] = "" # set a valid wav

    return if self[:data][:grid_content].nil?
    return if end_call?

    decoder = case self[:data][:program]
      when :mobile
        Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_NB))
      else
        Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_UWB))
    end

    # enable enhancement
    enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
    Speex.decoder_ctl(decoder, Speex::SET_ENH, enhancement_ptr)
    
    # get frame size
    frame_size_ptr = FFI::MemoryPointer.new(:int32).write_uint 0
    Speex.decoder_ctl(decoder, Speex::GET_FRAME_SIZE, frame_size_ptr)
    frame_size = frame_size_ptr.get_uint(0)
    
    raw_content = StringIO.new self[:data][:grid_content]
    wave_buffer = ''
    
    bits = Speex::Bits.new
    Speex.bits_init(bits.pointer)
    
    while not raw_content.eof? do
      # read one chunk
      len = raw_content.read(4).unpack("L").shift
      chunk = raw_content.read(len)

      unless chunk.nil?
        buffer = FFI::MemoryPointer.new(:char, chunk.size)
        buffer.put_bytes(0, chunk, 0, chunk.size)

        Speex.bits_read_from(bits.pointer, buffer, buffer.size)
        
        output_buffer = FFI::MemoryPointer.new(:float, frame_size)
        Speex.decode(decoder, bits.pointer, output_buffer)
        
        # Speex outputs 32 bits float samples, wave needs 16 bit integers
        self[:wav] = output_buffer.read_array_of_float(frame_size)
      end
    end
    
    Speex.bits_destroy(bits.pointer)
    Speex.decoder_destroy(decoder)
  end
  
  def type
    :call
  end
  
end

end # RCS::
