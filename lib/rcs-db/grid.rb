require 'mongoid'
require 'rcs-common/trace'
require 'rcs-common/gridfs'

module RCS
  module DB
    class GridFS
      extend RCS::Tracer

      DEFAULT_GRID_NAME = 'grid'
      DEFAULT_CHUNK_SIZE = RCS::Common::GridFS::Bucket::DEFAULT_CHUNK_SIZE

      class << self

        def collection_name(coll)
          coll ? "#{DEFAULT_GRID_NAME}.#{coll}" : DEFAULT_GRID_NAME
        end

        def session
          Mongoid.default_session
        end

        def get_bucket(collection = nil, options = {})
          options[:session] = session
          RCS::Common::GridFS::Bucket.new(collection_name(collection), options)
        end

        def create_collection(collection = nil)
          bucket = get_bucket(collection, lazy: false)

          # Enable sharding only if not enabled
          chunks = bucket.chunks_collection
          Shard.set_key(chunks, files_id: 1) unless Shard.sharded?(chunks)
        end

        def put(content, file_attributes = {}, collection = nil)
          raise "Cannot put into the grid: content is empty" if content.nil? or content.bytesize.zero?

          bucket = get_bucket(collection, lazy: false)
          bucket.put(content, file_attributes)
        rescue Exception => ex
          trace(:error, "Cannot put content into the Grid: #{collection_name(collection)} #{file_attributes.inspect} #{ex.message}")
          raise
        end

        def get(id, collection = nil)
          id = id.first if id.kind_of?(Array)
          get_bucket(collection).get(id)
        rescue Exception => e
          trace :error, "Cannot get content from the Grid: #{collection_name(collection)} #{e.message}"
          raise
        end

        def append(id, content, collection = nil)
          get_bucket(collection).append(id, content, md5: false)
        rescue Exception => e
          trace :error, "Cannot append content to the grid file #{id} of collection #{collection_name(collection)}: #{e.message}"
          raise
        end

        def delete(id, collection = nil)
          id = id.first if id.kind_of?(Array)
          get_bucket(collection).delete(id)
        rescue Exception => e
          trace :error, "Cannot delete content from the Grid: #{collection_name(collection)} #{e.message}"
          raise
        end

        def to_tmp(id, collection = nil)
          id = id.first if id.kind_of?(Array)
          grid_file = get_bucket(collection).get(id)
          raise "Grid content is nil, cannot find file #{id}" unless grid_file

          tempfile_path = Config.instance.temp("#{id}-%f" % Time.now)

          File.open(tempfile_path, 'wb+') do |file|
            file.write grid_file.read(grid_file.chunk_size) until grid_file.eof?
          end

          tempfile_path
        rescue Exception => e
          trace :error, "Cannot save to tmp from the Grid: #{collection_name(collection)}"
          trace :error, e.message
          retry if attempt ||= 0 and attempt += 1 and attempt < 5
          raise
        end

        def delete_by_agent(agent, collection = nil)
          delete_by_filename(agent, collection)
        end

        def drop_collection(collection)
          get_bucket(collection).drop
        end

        def get_by_filename(filename, collection = nil)
          bucket = get_bucket(collection)
          bucket.files_collection.find(filename: filename).select(_id: 1, length: 1)
        rescue Exception => e
          trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
          return []
        end

        def delete_by_filename(filename, collection = nil)
          bucket = get_bucket(collection)

          bucket.files_collection.find(filename: filename).select(_id: 1, length: 1).each  do |e|
            bucket.delete(e["_id"])
          end
        rescue Exception => e
          trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
          return []
        end

        def get_distinct_filenames(collection = nil)
          bucket = get_bucket(collection)
          bucket.files_collection.find.distinct("filename")
        rescue Exception => e
          trace :error, "Cannot get content from the Grid: #{collection_name(collection)}"
          return []
        end
      end
    end
  end
end
