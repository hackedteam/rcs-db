require 'ffi'
require 'stringio'

class Wave

  def initialize(num_channels, sample_rate, wav_data)
    @num_channels = num_channels
    @sample_rate = sample_rate
    @wav_data = wav_data
  end
  
  def self.main_header(size)
    header = StringIO.new
    header.write "RIFF"
    header.write [size].pack("L")
    header.write "WAVE"
    return header.string
  end
  
  def self.chunk_header(num_channels, sample_rate)
    header = StringIO.new
    header.write "fmt "
    header.write [16].pack("L")
    header.write [1].pack("S")
    header.write [num_channels].pack("S")
    header.write [sample_rate].pack("L")
    bits_per_sample = 16
    block_align = (bits_per_sample / 8) * num_channels
    avg_bytes_sec = sample_rate * block_align
    header.write [avg_bytes_sec].pack("L")
    header.write [block_align].pack("S")
    header.write [bits_per_sample].pack("S")
    return header.string
  end
  
  def self.data_header(size)
    header = StringIO.new
    header.write "data"
    header.write [size].pack("L")
    return header.string
  end
  
end