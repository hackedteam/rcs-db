require 'stringio'

class Wave

  def initialize(num_channels, sample_rate, wav_data)
    @num_channels = num_channels
    @sample_rate = sample_rate
    @wav_data = wav_data
  end
  
  def main_header
    header = StringIO.new
    header.write "RIFF"
    header.write [36 + @wav_data.bytesize].pack("L")
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
    bits_per_sample = 16
    block_align = (bits_per_sample / 8) * @num_channels
    avg_bytes_sec = @sample_rate * block_align
    header.write [avg_bytes_sec].pack("L")
    header.write [block_align].pack("S")
    header.write [bits_per_sample].pack("S")
    return header.string
  end
  
  def data_header
    header = StringIO.new
    header.write "data"
    header.write [@wav_data.bytesize].pack("L")
    return header.string
  end
  
  def write(file_name)
    File.open(file_name, 'wb+') do |f|
      f.write main_header
      f.write chunk_header
      f.write data_header
      f.write @wav_data
    end
  end
end
