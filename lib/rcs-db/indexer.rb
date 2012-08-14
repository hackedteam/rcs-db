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
      t = ::Item.where({:_kind => 'target', :name => Regexp.new(target, true)}).first
      if t.nil?
        puts "Target not found"
        return 1
      end
      collections.keep_if {|x| x["evidence.#{t[:_id]}"]}
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
    chunk = 500
    cursor = 0
    count = evidence.where(:kw.exists => false).count
    puts "#{count} evidence to be indexed"

    # divide in chunks to avoid timeouts
    while cursor < count do

      evidence.where(:kw.exists => false).limit(chunk).skip(cursor).each do |evi|
        kw = keywordize(evi[:type], evi[:data], evi[:note])

        evi[:kw] = kw
        evi.save
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

    # don't index those types
    return [] if ['filesystem', 'mic', 'ip'].include? type

    return keywordize_position(data, note) if type == 'position'

    kw = SortedSet.new

    data.each_value do |value|
      next unless value.is_a? String
      kw += value.keywords
    end

    kw += note.keywords unless note.nil?

    kw.to_a
  end

  def self.keywordize_position(data, note)
    kw = SortedSet.new

    kw += data['latitude'].to_s.keywords unless data['latitude'].nil?
    kw += data['longitude'].to_s.keywords unless data['longitude'].nil?

    unless data['address'].nil?
      data['address'].each_value do |add|
        kw += add.keywords
      end
    end
    unless data['cell'].nil?
      data['cell'].each_value do |cell|
        kw << cell.to_s
      end
    end
    unless data['wifi'].nil?
      data['wifi'].each do |wifi|
        kw += [wifi['mac'].keywords, wifi['bssid'].keywords ].flatten
      end
    end

    data.each_value do |value|
      next unless value.is_a? String
      kw += value.keywords
    end

    kw += note.keywords unless note.nil?

    kw.to_a
  end

end
