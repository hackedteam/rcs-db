require 'stringio'

class Wave

  def initialize(num_channels, sample_rate)
    @num_channels = num_channels
    @sample_rate = sample_rate
    @header_written = false
  end
  
  def main_header(data_size)
    header = StringIO.new
    header.write "RIFF"
    header.write [36 + (data_size)].pack("L")
    header.write "WAVE"
    return header.string
  end
  
  def chunk_header
    header = StringIO.new
    header.write "fmt "
    header.write [16].pack("L")
    header.write [1].pack("S")
    header.write [@num_channels].pack("S")
    header.write [@sample_rate].pack("L")
    bits_per_sample = 16 # short
    block_align = (bits_per_sample / 8) * @num_channels
    avg_bytes_sec = @sample_rate * block_align
    header.write [avg_bytes_sec].pack("L")
    header.write [block_align].pack("S")
    header.write [bits_per_sample].pack("S")
    return header.string
  end
  
  def data_header(data_size)
    header = StringIO.new
    header.write "data"
    header.write [data_size].pack("L")
    return header.string
  end

  def write(file_name, wav_ary)
    File.open(file_name, 'ab') do |f|
      unless @header_written
        f.write main_header(wav_ary.size * 2)
        f.write chunk_header
        f.write data_header(wav_ary.size * 2)
        @header_written = true
      end
      buffer = wav_ary.collect {|s| s.to_i}
      f.write buffer.pack('s*')
    end

    size = File.size(file_name) - 36

    File.open(file_name, 'rb+') do |f|
      f.write main_header(size)
      f.write chunk_header
      f.write data_header(size)
    end
  end
end
