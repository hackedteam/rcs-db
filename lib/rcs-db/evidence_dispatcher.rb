# from RCS::Common
require 'rcs-common/trace'

require_relative 'shard'

module RCS
module DB

class EvidenceDispatcher
  include Singleton
  include RCS::Tracer
  
  def initialize
    @shards = Array.new

    # for each known shard, prepare a list of notification
    Shard.all['shards'].each_with_index do |shard, index|
      puts "#{index} #{shard}"
      ip, port = shard['host'].split(':')
      puts "#{index} - SHARD #{shard['_id']} IP #{ip}"
      @shards[index] = {host: ip, queue: []}
    end
    # worker polling thread, check for health status
  end
  
  def notify(evidence_id, ident, instance)
    agent = ::Item.agents.where({ident: ident, instance: instance}).first
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    
    puts @shards.inspect
    
    hash_string = "#{ident}(#{instance})"
    shard_idx = hash_string.hash % @shards.length
    puts "EVIDENCE FROM #{ident} (#{instance}) -> SHARD #{@shards[shard_idx][:host]}"

    trace :info, "Processing evidence #{evidence_id} for agent #{agent[:name]} "
    return true
  end
  
end # EvidenceDispatcher

end # ::DB
end # ::RCS
