#
# GridFS management
#

require 'mongo'
require 'mongoid'

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

class GridFS
  extend RCS::Tracer

  DEFAULT_GRID_NAME = 'grid'

  class << self
    
    def collection_name(coll)
      coll.nil? ? DEFAULT_GRID_NAME : DEFAULT_GRID_NAME + '.' + coll
    end
    
    def put(content, opts = {}, collection = nil)
      begin
        raise "Cannot put into the grid: content is empty" if content.nil?

        db = DB.instance.new_mongo_connection
        grid = Mongo::Grid.new db, collection_name(collection)
        grid_id = grid.put(content, opts)

        # enable sharding only if not enabled
        chunks = db.collection(collection_name(collection) + '.chunks')
        Shard.set_key(chunks, {files_id: 1}) unless chunks.stats['sharded']

        return grid_id
      rescue Exception => e
        trace :error, "Cannot put content into the Grid: #{collection_name(collection)} #{opts.inspect} #{e.message}"
        raise
      end
    end

    def get(id, collection = nil)
      #raise "Id must be a BSON::ObjectId" unless id.is_a? BSON::ObjectId
      begin
        db = DB.instance.new_mongo_connection
        grid = Mongo::Grid.new db, collection_name(collection)
        return grid.get id
      rescue Exception => e
        trace :error, "Cannot get content from the Grid: #{collection_name(collection)} #{e.message}"
        raise
      end
    end
    
    def delete(id, collection = nil)
      begin
        db = DB.instance.new_mongo_connection
        grid = Mongo::Grid.new db, collection_name(collection)
        return grid.delete id
      rescue Exception => e
        trace :error, "Cannot delete content from the Grid: #{collection_name(collection)} #{e.message}"
        raise
      end
    end

    def to_tmp(id, collection = nil)
      begin
        file = self.get id, collection
        raise "Grid content is nil" if file.nil?
        temp = File.open(Config.instance.temp("#{id}-%f" % Time.now), 'wb+')
        temp.write file.read(65536) until file.eof?
        temp.close
        return temp.path
      rescue Exception => e
        trace :error, "Cannot save to tmp from the Grid: #{collection_name(collection)}"
        trace :error, e.message
        retry if attempt ||= 0 and attempt += 1 and attempt < 5
        raise
      end
    end

    def delete_by_agent(agent, collection = nil)
      items = get_by_filename(agent, collection_name(collection))
      items.each {|item| delete(item["_id"], collection_name(collection))}
    end

    def drop_collection(name)
      db = DB.instance.new_mongo_connection
      db.drop_collection DEFAULT_GRID_NAME + '.' + name + '.files'
      db.drop_collection DEFAULT_GRID_NAME + '.' + name + '.chunks'
    end

    def get_by_filename(filename, collection = nil)
      begin
        files = DB.instance.new_mongo_connection.collection( collection_name(collection) + ".files")
        return files.find({"filename" => filename}, :fields => ["_id", "length"])
      rescue Exception => e
        trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
        return []
      end
    end

    def delete_by_filename(filename, collection = nil)
      begin
        files = DB.instance.new_mongo_connection.collection( collection_name(collection) + ".files")
        files.find({"filename" => filename}, :fields => ["_id", "length"]).each  do |e|
          delete(e["_id"], collection)
        end
      rescue Exception => e
        trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
        return []
      end
    end

    def get_distinct_filenames(collection = nil)
      begin
        files = DB.instance.new_mongo_connection.collection( collection_name(collection) + ".files")
        return files.distinct("filename")
      rescue Exception => e
        trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
        return []
      end
    end

  end
end

end # ::DB
end # ::RCS