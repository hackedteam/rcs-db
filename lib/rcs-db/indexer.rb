#!/usr/bin/env ruby

#
#
#

require 'mongoid'

require 'rcs-common/trace'

require_relative 'db_objects/evidence'

class Indexer

  def self.run
    puts "Full text search keyword indexer running..."

    # this is required for mongoid >= 2.4.2
    ENV['MONGOID_ENV'] = 'yes'

    Mongoid.load!(Dir.pwd + '/config/mongoid.yaml')
    Mongoid.configure do |config|
      config.master = Mongo::Connection.new('127.0.0.1', 27017, pool_size: 50, pool_timeout: 15).db('rcs')
    end

    puts "Connected to MongoDB..."

    # load the collection list
    collections = Mongoid::Config.master.collection_names
    collections.keep_if {|x| x['evidence.']}
    collections.delete_if {|x| x['grid.'] or x['files'] or x['chunks']}

    puts "Found #{collections.count} collection to be indexed..."

    collections.each do |coll_name|
      puts
      puts "Indexing #{coll_name}"
      #coll = db.collection(coll_name)
      current = Evidence.collection_class(coll_name.split('.').last)
      index_collection(current)
    end
  end

  def self.index_collection(evidence)
    chunk = 100
    cursor = 0
    count = evidence.where(:kw.exists => false).count
    puts "#{count} evidence to be indexed"

    # divide in chunks to avoid timeouts
    while cursor < count do

      evidence.where(:kw.exists => false).limit(chunk).skip(cursor).each do |evi|
        #puts "."
        kw = keywordize(evi[:type], evi[:data])

        puts kw.inspect
      end

      cursor += chunk
      puts "#{count - cursor} evidence left" if count - cursor > 0
    end
  end


  def self.keywordize(type, data)
    kw = []
    data.each_value do |value|
      next unless value.is_a? String
      kw += value.keywords
    end
    kw.uniq!
  end

end


if __FILE__ == $0
  Indexer.run
end