module RCS
module Audio

class AudioProcessor
  
  def initialize
    @pieces = []
  end

  def feed(piece)
    @pieces < piece
  end

  def to_s
    require 'pp'
    pp @pieces
  end

end

end # Audio::
end # RCS::