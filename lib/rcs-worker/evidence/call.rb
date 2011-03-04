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
        
    raw_content = StringIO.new @content
    @wav = ''

    bits = Speex::Bits.new
    
    while not raw_content.eof? do
      len = raw_content.read(4).unpack("L").shift
      chunk = raw_content.read(len)
      unless chunk.nil?
        buffer = FFI::MemoryPointer.new(chunk.size).write_string(chunk)
        Speex.bits_init(bits.pointer)
        Speex.bits_read_from(bits.pointer, buffer, chunk.size)
        output_buffer = FFI::MemoryPointer.new(:float, frame_size)
        Speex.decode(decoder, bits.pointer, output_buffer)
        @wav += output_buffer.read_string
      end
    end
    
    Speex.bits_destroy(bits.pointer)
    Speex.decoder_destroy(decoder)
    
    channel = RCS::Worker::Channel.new self.sample_rate, self.start_time
    channel.feed(@wav)
    channel.to_wavfile

  end
  
end

end # RCS::
