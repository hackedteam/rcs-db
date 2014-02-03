require_relative 'database_scoped'

module RCS
  module Money
    class BlkFile
      include Mongoid::Document
      include DatabaseScoped

      NULL_PART_BEGIN_WITH = "\x00\x00\x00\x00".force_encoding('BINARY')
      COLLECTION_NAME = 'blk_files'

      store_in(collection: COLLECTION_NAME)

      field :name,               type: String
      field :path,               type: String
      field :imported_bytes,     type: Integer, default: 0
      field :imported_blocks,    type: Integer, default: 0
      field :null_part_start_at, type: Integer

      index({name: 1}, {unique: true})

      def filesize
        @filesize ||= File.size(path)
      end

      def imported?
        filesize == imported_bytes
      end

      def import_percentage
        ((100.0 * imported_bytes) / filesize).round(2)
      end

      def null_part_reduced?
        @_null_part_reduced || begin
          File.open(path) do |file|
            file.seek(null_part_start_at)
            return file.read(NULL_PART_BEGIN_WITH.size) != NULL_PART_BEGIN_WITH
          end
        end
      end

      def null_part?
        null_part_start_at and imported_bytes <= null_part_start_at
      end

      def real_import_percentage
        if null_part? and null_part_reduced?
          return(import_percentage)
        end

        not_null_size = null_part? ? null_part_start_at : filesize
        ((100.0 * imported_bytes) / not_null_size).round(2)
      end
    end
  end
end