module RCS

require_relative '../speex'
require_relative '../call_processor'
require_relative 'audio_evidence'

module CallProcessing
  extend AudioEvidence

  attr_reader :wav

  def process

    self[:wav] = []

    return if self[:data][:grid_content].nil?

    return if self[:end_call]

    codec = :amr if self[:data][:sample_rate] & LOG_AUDIO_AMR == 1
    codec ||= :speex
    self[:data][:sample_rate] &= ~LOG_AUDIO_AMR # clear codec bit if set

    data = self[:data][:grid_content]
    case self[:data][:program]
      when "Mobile"
        self[:wav] = Speex.get_wav_frames(data, Speex::MODEID_NB) if codec == :speex
        self[:wav] = AMR.get_wav_frames data if codec == :amr # AMR.get_wav_frames data if codec == :amr
      else
        self[:wav] = Speex.get_wav_frames(data, Speex::MODEID_UWB) if codec == :speex
        self[:wav] = AMR.get_wav_frames data if codec == :amr
    end

    #wav = Wave.new 1, self[:data][:sample_rate]
    #wav.write "#{self[:data][:peer]}_#{self[:data][:start_time].to_f}_#{self[:data][:channel]}.wav", self[:wav]
  end
  
  def type
    :call
  end
  
end

end # RCS::
