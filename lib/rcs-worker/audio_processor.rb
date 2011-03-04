module RCS
module Worker

require 'ffi'
require 'rcs-common/trace'
require 'rcs-worker/speex'

class AudioProcessor
  include Tracer
  require 'pp'
  
  def initialize
    @calls = {}
    
  end
  
  def decode_speex(stream)
    bits = Speex::Bits.new
    Speex.bits_init(bits.pointer);
    stream.each do |chunk|
      puts "Attempt to decode #{chunk.size} bytes."
      Speex.bits_read_from(bits.pointer, FFI::MemoryPointer.from_string(chunk), chunk.size)
	    output_buffer = FFI::MemoryPointer.new(:float, @frame_size)
      Speex.decode(@encoder, bits.pointer, output_buffer)
      File.open('test.wav', 'ab') {|f| f.write(output_buffer.get_string(@frame_size)) }
    end
  end
  
  def feed(piece)
    if piece.callee.size == 0
      #trace :debug, "ignoring sample, no calling info ..."
      return
    end
    
    # check if a new call is beginning
    call_id = "#{piece.callee}:#{piece.start_time}"
    if not @calls.has_key? call_id
      #trace :debug, "issuing a new call for #{call_id}"
      @calls[call_id] = Hash.new
    end
    
    call = @calls[call_id]
    channel = piece.channel
    
    # add sample to correct channel of call
    
    if not call.has_key? channel
      call[channel] = Array.new
    end
    
    #trace :debug, "feeding #{piece.content.size} bytes of samples for call #{call_id}, channel #{channel}"
    call[channel] << piece
  end
  
  def make_continuous_stream(channel)
    sample = channel.shift
    channel.each do |s|
      #if sample.stop_time == s.start_time
      #sample = s
    end
  end
  
  def to_s
    @calls.keys.each do |k|
      trace :debug, "call #{k}"
      @calls[k].keys.each do |c|
        bytes = 0
        @calls[k][c].each do |s|
          trace :debug, "\t\t#{s.start_time.usec}:#{s.stop_time.usec}"
          bytes += s.content.size
          decode_speex(s.content)
        end
        trace :debug, "\t- #{c} #{bytes}"
      end
    end
  end
  
end

end # Audio::
end # RCS::
