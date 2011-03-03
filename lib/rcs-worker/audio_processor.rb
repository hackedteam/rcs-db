module RCS
module Worker

require 'rcs-common/trace'
require 'rcs-worker/speex'

class AudioProcessor
  include Tracer
  require 'pp'
  
  def initialize
    @calls = {}
    
    @encoder = Speex.decoder_init(Speex.lib_get_mode(Speex::MODEID_NB))
    
    enhancement_ptr = FFI::MemoryPointer.new(:int32).write_uint 1
    Speex.decoder_ctl(@encoder, Speex::SET_ENH, enhancement_ptr);
    framesize_ptr = FFI::MemoryPointer.new(:int32).write_uint 0
    Speex.decoder_ctl(@encoder, Speex::GET_FRAME_SIZE, framesize_ptr);
    #trace :debug, "Speex framesize: #{framesize_ptr.get_uint(0)}"
  end
  
  def feed(piece)
    if piece.info[:callee].size ==0
      #trace :debug, "ignoring sample, no calling info ..."
      return
    end
    
    # check if a new call is beginning
    call_id = piece.info[:callee]
    if not @calls.has_key? call_id
      #trace :debug, "issuing a new call for #{call_id}"
      @calls[call_id] = Hash.new
    end
    
    call = @calls[call_id]
    channel = piece.info[:channel]
    
    # add sample to correct channel of call
    
    if not call.has_key? channel
      call[channel] = Array.new
    end
    
    #trace :debug, "feeding #{piece.content.size} bytes of samples for call #{call_id}, channel #{channel}"
    call[channel] << piece
  end
  
  def process
  
  end
  
  def to_s
    @calls.keys.each do |k|
      trace :debug, "call #{k}"
      @calls[k].keys.each do |c|
        bytes = 0
        @calls[k][c].each do |s|
          bytes += s.content.size
        end
        trace :debug, "\t- #{c} #{bytes}"
      end
    end
  end
  
end

end # Audio::
end # RCS::
