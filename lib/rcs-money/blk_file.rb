require_relative 'database_scoped'

module RCS
  module Money
    class BlkFile
      include Mongoid::Document
      include DatabaseScoped

      COLLECTION_NAME = 'blk_files'

      store_in(collection: COLLECTION_NAME)

      field :name,               type: String
      field :path,               type: String
      field :imported_bytes,     type: Integer, default: 0
      field :imported_blocks,    type: Integer, default: 0
      field :null_block_head_at, type: Integer

      index({name: 1}, {unique: true})

      # Filesize may change (64mb, 128 mb, etc.)
      # do not store it
      def filesize
        @filesize ||= File.size(path)
      end

      def imported?
        filesize == imported_bytes
      end

      def import_percentage
        ((100.0 * imported_bytes) / filesize).round(2)
      end

      def null_part?
        null_block_head_at and imported_bytes <= null_block_head_at
      end

      def real_import_percentage
        not_null_size = null_part? ? null_block_head_at : filesize
        ((100.0 * imported_bytes) / not_null_size).round(2)
      end
    end
  end
end