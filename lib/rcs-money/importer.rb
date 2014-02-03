require 'rcs-common/trace'
require_relative 'tx'
require_relative 'blocks_folder'

module RCS
  module Money
    class Importer
      include RCS::Tracer

      def initialize(currency, **options)
        @currency = currency
        @cli = options[:cli]
        Bitcoin.network = @currency
      end

      def run
        blocks_folder = BlocksFolder.discover(@currency)

        if blocks_folder
          import_blocks_folder(blocks_folder)
        else
          puts "[#{@currency}] Unable to find blocks folder" if @cli
        end
      end

      def ensure_indexes
        @indexes_ensured ||= begin
          [Tx, BlkFile].each { |klass|
            puts "[#{@currency}] Creating indexs on #{klass.collection.name}" if @cli
            klass.for(@currency).create_indexes
          }
        end
      end

      def import_tx(tx)
        hash = tx.to_hash

        tx_attributes = {h: hash['hash'], i: [], o: []}

        tx_attributes[:o] = hash['out'].map do |h|
          out_address = Bitcoin::Script.from_string(h['scriptPubKey']).get_address
        end

        tx_attributes[:i] = hash['in'].map do |h|
          prev_out = h['prev_out']
          is_coinbase = prev_out['hash'] =~ /^0+$/

          if !is_coinbase
            # Select via moped (skip Mongoid)
            ref_tx = Tx.for(@currency).collection.find(h: prev_out['hash']).select(o: 1).first
            ref_tx || raise("Unable to find #{@currency} tx #{prev_out['hash']}")
            ref_tx_out = ref_tx['o']
            prev_out_address = ref_tx_out[prev_out['n']]
          else
            nil
          end
        end.compact

        # Insert via moped (skip Mongoid)
        # Prevent raising exception on duplicate key error (e.g. reimporting the same block,
        # because import process is tracked once every N blocks)
        Tx.for(@currency).with(safe: false).collection.insert(tx_attributes)
      end

      def import_blocks_folder(blocks_folder)
        blocks_folder.files.each { |blk_file| import_blk_file(blk_file) }
      end

      def import_blk_file(blk_file)
        return if blk_file.imported?

        msg = "[#{@currency}] Start importing #{blk_file.path} from offeset #{blk_file.imported_bytes} (filesize is #{blk_file.filesize})"
        @cli ? puts("#{msg}") : trace(:info, msg)

        ensure_indexes

        filesize = blk_file.filesize
        readed_bytes = blk_file.imported_bytes
        readed_blocks = blk_file.imported_blocks

        # if the blk file is new, save the import process every 1024 blocks
        # otherwise save it every block
        n = readed_bytes.zero? ? 1024 : 1

        File.open(blk_file.path) do |file|
          file.seek(blk_file.imported_bytes)

          until file.eof?
            magic = file.read(4)
            break if magic.size != 4

            # Block terminated / incomplete block
            if magic == null_block_head
              blk_file.null_part_start_at = readed_bytes
              break
            end

            raise "Invalid network magic"  unless block_head == magic

            size_raw = file.read(4)
            break if size_raw.size != 4

            size = size_raw.unpack("L")[0]
            readed_bytes += 4 + 4 + size

            percentage = (readed_bytes * 100.0 / blk_file.filesize).round(2)

            print "\r[#{@currency}] #{blk_file.name}, #{percentage}%" if @cli

            blk_raw_content = file.read(size)
            break if blk_raw_content.size != size

            block = Bitcoin::Protocol::Block.new(blk_raw_content)
            block.tx.each { |tx| import_tx(tx) }

            # Keep track of the importing process
            blk_file.imported_bytes = readed_bytes
            blk_file.imported_blocks = (readed_blocks += 1)

            # And save it every N blocks, where N is large enough not to
            # interfere with the write on tx collection
            blk_file.save! if readed_blocks % n == 0
          end
        end

        blk_file.save!

        msg = "[#{@currency}] Import of #{blk_file.path} complete"
        @cli ? puts("\n#{msg}") : trace(:info, msg)
      end

      def block_head
        @block_head ||= Bitcoin::NETWORKS[@currency][:magic_head].force_encoding("BINARY")
      end

      def null_block_head
        BlkFile::NULL_PART_BEGIN_WITH
      end
    end
  end
end
