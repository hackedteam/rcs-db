# from RCS::Common
require 'rcs-common/trace'

module AudioEvidence

  def self.extended(base)
    base.send :include, InstanceMethods
    base.send :include, RCS::Tracer

    base.instance_exec do
      # default values
    end
  end
  
  module InstanceMethods

    LOG_AUDIO_SPEEX = 0x0
    LOG_AUDIO_AMR = 0x1

    def get_agent
      ::Item.agents.where({instance: info[:instance]}).first
    end

    def store(agent, target)
      trace :debug, "storage of audio evidence still not implemented!"
    end
  end

end # AudioEvidence
