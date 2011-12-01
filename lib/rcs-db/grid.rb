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
        db = Mongoid.database
        grid = Mongo::Grid.new db, collection_name(collection)
        grid_id = grid.put(content, opts)

        # enable sharding only if not enabled
        chunks = db.collection(collection_name(collection) + '.chunks')
        Shard.set_key(chunks, {files_id: 1}) unless chunks.stats['sharded']

        return grid_id
      rescue Exception => e
        trace :error, "Cannot put content into the Grid: #{collection_name(collection)} #{opts.inspect} #{e.message}"
        return nil
      end
    end

    def get(id, collection = nil)
      begin
        db = Mongoid.database
        grid = Mongo::Grid.new db, collection_name(collection)
        return grid.get id
      rescue Exception => e
        trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
        return nil
      end
    end

    def delete(id, collection = nil)
      begin
        db = Mongoid.database
        grid = Mongo::Grid.new db, collection_name(collection)
        return grid.delete id
      rescue Exception => e
        trace :error, "Cannot delete content from the Grid: #{collection_name(collection)}"
        return nil
      end
    end

    def to_tmp(id, collection = nil)
      file = self.get id, collection
      temp = File.open(Config.instance.temp("#{id}-%f" % Time.now), 'wb')
      temp.write file.read
      temp.flush
      temp.close
      return temp.path
    end

    def delete_by_agent(agent, collection = nil)
      items = get_by_filename(agent, collection_name(collection))
      items.each {|item| delete(item["_id"], collection_name(collection))}
    end

    def get_by_filename(filename, collection = nil)
      begin
        files = Mongoid.database.collection( collection_name(collection) + ".files")
        return files.find({"filename" => filename}, :fields => ["_id", "length"])
      rescue Exception => e
        # TODO handle the correct exception
        puts e.message
      end
    end

    def get_distinct_filenames(collection = nil)
      begin
        files = Mongoid.database.collection( collection_name(collection) + ".files")
        return files.distinct("filename")
      rescue Exception => e
        # TODO handle the correct exception
        puts e.message
      end

    end

  end
end

end # ::DB
end # ::RCS