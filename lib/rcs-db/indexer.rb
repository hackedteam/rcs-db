#!/usr/bin/env ruby

#
# Full text search keyword indexer
#

require 'mongoid'
require 'set'

require 'rcs-common/trace'

require_relative 'db_objects/evidence'

class Indexer

  def self.run(target)
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

    if target.downcase == 'all'
      collections.keep_if {|x| x['evidence.']}
    else
      id = ::Item.where({:_kind => 'target', :name => Regexp.new(target)}).first[:_id]
      collections.keep_if {|x| x["evidence.#{id}"]}
    end

    collections.delete_if {|x| x['grid.'] or x['files'] or x['chunks']}

    puts "Found #{collections.count} collection to be indexed..."

    collections.each_with_index do |coll_name, index|
      tid = coll_name.split('.').last
      t = ::Item.find(tid)
      puts
      puts "Indexing #{t.name} - %.0f %%" % ((index + 1) * 100 / collections.count)
      current = Evidence.collection_class(tid)
      index_collection(current)
    end

    return 0
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
        kw = keywordize(evi[:type], evi[:data], evi[:note])

        #puts evi.type if kw.inspect.size > 1000
      end

      cursor += chunk
      if count - cursor > 0
        print "#{count - cursor} evidence left - %.2f %%     \r" % (cursor*100/count)
      else
        puts 'done - 100 %                        '
      end
    end

  end


  def self.keywordize(type, data, note)
    kw = SortedSet.new

    data.each_value do |value|
      next unless value.is_a? String
      kw += value.keywords
    end

    kw += note.keywords unless note.nil?

    kw.to_a
  end

end


if __FILE__ == $0
  Indexer.run
end