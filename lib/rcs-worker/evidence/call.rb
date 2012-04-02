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
    self[:wav] = []

    return if self[:data][:grid_content].nil?
    return if end_call?

    # speex decode
    case self[:data][:program]
      when :mobile
        self[:wav] = Speex.get_wav_frames(self[:data][:grid_content], Speex::MODEID_NB)
      else
        self[:wav] = Speex.get_wav_frames(self[:data][:grid_content], Speex::MODEID_UWB)
    end
  end
  
  def type
    :call
  end
  
end

end # RCS::
