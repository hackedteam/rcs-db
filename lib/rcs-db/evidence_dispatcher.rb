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
  end

  def shard_id(ident, instance)
    hash_string = "#{ident}:#{instance}"
    idx = Zlib::crc32(hash_string) % Shard.count
    @shards.keys[idx]
  end

  def address(shard)
    @shards[shard]
  end
end # EvidenceDispatcher

end # ::DB
end # ::RCS
