require 'bitcoin-ruby'

$BLOCK_FOLDER = "/Users/danielemolteni/Library/Application Support/Feathercoin/blocks"
$feathercoin_block_head = "\xFB\xC0\xB6\xDB".force_encoding('BINARY')
$feathercoin_block_tail = "\x00\x00\x00\x00".force_encoding('BINARY')

def import(filename)
  puts "Importing #{filename}"

  File.open(filename) do |file|
    until file.eof?
      magic = file.read(4)

      if magic == $feathercoin_block_tail
        puts "Block terminated, incomplete block?"
        break
      end

      raise "invalid network magic"  unless $feathercoin_block_head == magic
      size = file.read(4).unpack("L")[0]

      blk_raw_content = file.read(size)

      blk = Bitcoin::Protocol::Block.new(blk_raw_content)
      yield(blk) if block_given?
    end
  end
end

import("#{$BLOCK_FOLDER}/blk00002.dat") do |block|
  # hash = block.to_hash
  # do something!!
end
