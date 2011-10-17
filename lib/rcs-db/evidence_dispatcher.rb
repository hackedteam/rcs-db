# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class EvidenceDispatcher
  include Singleton
  include RCS::Tracer
  
  def notify(evidence_id, ident, instance)
    agent = ::Item.agents.where({ident: ident, instance: instance}).first
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    trace :info, "Processing evidence #{evidence_id} for agent #{agent[:name]} "
    return true
  end
  
end # EvidenceDispatcher

end # ::DB
end # ::RCS
