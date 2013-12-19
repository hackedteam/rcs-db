require 'digest'

module B58Encode

  extend self
  
  @@__b58chars = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
  @@__b58base = @@__b58chars.bytesize

  def self.encode(v)
    # encode v, which is a string of bytes, to base58.    

    long_value = 0
    
    v.chars.to_a.reverse.each_with_index do |c, i| 
      long_value += (256**i) * c.ord
    end

    result = ''
    
    while long_value >= @@__b58base do
      div, mod = long_value.divmod(@@__b58base)
      result = @@__b58chars[mod] + result
      long_value = div
    end
      
    result = @@__b58chars[long_value] + result

    # Bitcoin does a little leading-zero-compression:
    # leading 0-bytes in the input become leading-1s
    nPad = 0
    v.chars.to_a.each do |c|
      if c == "\0"
        nPad += 1
      else
        break
      end
    end
    
    return (@@__b58chars[0]*nPad) + result
  end
  
  def self.decode(v, length)
    #decode v into a string of len bytes

    long_value = 0

    v.chars.to_a.reverse.each_with_index do |c, i| 
      long_value += @@__b58chars.index(c) * (@@__b58base**i)
    end
    
    result = ''
    
    while long_value >= 256 do
      div, mod = long_value.divmod(256)
      result = mod.chr + result
      long_value = div
    end
    
    result = long_value.chr + result

    nPad = 0
    v.chars.to_a.each do |c|
      if c == @@__b58chars[0]
         nPad += 1
      else
         break
      end
    end
    
    result = 0.chr*nPad + result
    
    if !length.nil? and result.size != length
      return nil
    end

    return result  
  end
  
  def hash_160(public_key)
    h1 = Digest::SHA256.new.digest(public_key)
    h2 = Digest::RMD160.new.digest(h1)
    return h2
  end

  def public_key_to_bc_address(public_key, version = "\x00")
    h160 = hash_160(public_key)
    return hash_160_to_bc_address(h160, version=version)
  end

  def hash_160_to_bc_address(h160, version = "\x00")
    vh160 = version + h160
    h3 = Digest::SHA256.new.digest(Digest::SHA256.new.digest(vh160))
    addr = vh160 + h3[0..3]
    return self.encode(addr)
  end

  def bc_address_to_hash_160(addr)
    bytes = self.decode(addr, 25)
    return bytes[1..20]
  end
end

if __FILE__ == $0
  x = ['005cc87f4a3fdfe3a2346b6953267ca867282630d3f9b78e64'].pack('H*')
  encoded = B58Encode.encode(x)
  puts "#{encoded}, '19TbMSWwHvnxAKy12iNm3KdbGfzfaMFViT'"
  puts "#{B58Encode.decode(encoded, x.bytesize).unpack('H*')}, #{x.unpack('H*')}"
  
  key = "\x03\xF6\x8B\xCE\x1A\a\xC8W\xE0\xB8,\xAD\xF7\x18M\xAE\xC7\xCA\xEA+5;y\x1F1\xA0\xF6\xAF\ny\xA6\x83\x1C"
  address = "1MpehHPzn1dNFqNiZsLRiFEdk75Ck6FhN5"
  
  puts "#{B58Encode.public_key_to_bc_address(key)}, #{address}"
end