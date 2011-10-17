# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class EvidenceDispatcher
  include RCS::Tracer
  
  def notify(evidence_id, ident, instance)
    agent = Item..agents.where({ident: ident, instance: instance}).first
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    trace :info, "Notifying agent #{agent[:name]} of new evidence #{evidence_id}."
    return true
  end
  
end # EvidenceDispatcher

end # ::DB
end # ::RCS
