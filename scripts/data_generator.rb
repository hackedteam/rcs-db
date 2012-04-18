#!/usr/bin/env ruby
require 'benchmark'
require 'rcs-common'

require_relative '../lib/rcs-db/db_objects/evidence'
require_relative '../lib/rcs-db/db_objects/item'
require_relative '../lib/rcs-db/db_objects/group'
require_relative '../lib/rcs-db/db_objects/config'
require_relative '../lib/rcs-db/db_objects/user'

TARGET_ID = '4f8e7ea7aaef6609c400006d'
AGENT_ID = '4f8e8075aaef660c08000005'

EVIDENCE_TYPES = ["application", "chat", "clipboard", "device", "keylog", "password", "url"]

def create_evidence(coll)
  coll.create!() do |e|
    e.da = Time.now.getutc.to_i
    e.dr = Time.now.getutc.to_i
    e.type = EVIDENCE_TYPES.sample
    e.rel = 0
    e.blo = false
    e.aid = AGENT_ID
    e.data = {content: "this is a test for the count performance"}
  end
end

# connect to MongoDB
begin
  # this is required for mongoid >= 2.4.2
  ENV['MONGOID_ENV'] = 'yes'

  Mongoid.load!(Dir.pwd + '/../config/mongoid.yaml')
  Mongoid.configure do |config|
    config.master = Mongo::Connection.new('rcs-polluce', 27017, pool_size: 50, pool_timeout: 15).db('rcs')
    #config.logger = Logger.new $stdout
  end
rescue Exception => e
  puts e
  exit
end

inserts = 0
count = {}

Benchmark.bm(20) do |x|

  if false
    x.report('insert') do

      inserts = 50_000

      coll = Evidence.collection_class(TARGET_ID)

      inserts.times do |n|
        create_evidence(coll)
      end
    end
  end

  if true
    query = {aid: AGENT_ID}

    EVIDENCE_TYPES.each do |type|

      x.report('count ' + type) do
        query[:type] = type
        count[type] = ::Evidence.collection_class(TARGET_ID).where(query).count
      end
    end

  end

end

puts
puts "INSERT: #{inserts}"
total = 0
count.each_pair do |k,v|
  total += v
  puts "COUNT : #{k.rjust(15)} #{v}"
end
puts "COUNT : #{total}"
