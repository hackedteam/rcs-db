require 'sbdb'
require 'bdb'
require 'set'

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

    nPad = 0
    v.chars.to_a.each do |c|
      c == "\0" ? nPad += 1 : break
    end
    
    return (@@__b58chars[0] * nPad) + result
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
      c == @@__b58chars[0] ? nPad += 1 : break
    end
    result = 0.chr * nPad + result
    
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

  def public_key_to_bc_address(public_key, version = 0)
    h160 = hash_160(public_key)
    return hash_160_to_bc_address(h160, version)
  end

  def hash_160_to_bc_address(h160, version = 0)
    vh160 = version.chr + h160
    h3 = Digest::SHA256.new.digest(Digest::SHA256.new.digest(vh160))
    addr = vh160 + h3[0..3]
    return self.encode(addr)
  end

  def bc_address_to_hash_160(addr)
    bytes = self.decode(addr, 25)
    return bytes[1..20]
  end
end

class BCDataStream
  def initialize(string)
    @buffer = string
    @read_cursor = 0
  end
  
  def read_string()
    # Strings are encoded depending on length:
    # 0 to 252 :  1-byte-length followed by bytes (if any)
    # 253 to 65,535 : byte'253' 2-byte-length followed by bytes
    # 65,536 to 4,294,967,295 : byte '254' 4-byte-length followed by bytes
    # greater than 4,294,967,295 : byte '255' 8-byte-length followed by bytes of string

    if @buffer.eql? nil
      raise "not initialized"
    end
    
    begin
      length = self.read_compact_size()
    rescue Exception => e
      raise "attempt to read past end of buffer: #{e.message}"
    end

    return self.read_bytes(length)
  end
  
  def read_uint32(); return _read_num('I', 4).first;  end
  
  def read_bytes(length)
    result = @buffer[@read_cursor..@read_cursor+length-1]
    @read_cursor += length
    return result
  rescue Exception => e
    raise "attempt to read past end of buffer: #{e.message}"
  end
  
  def read_compact_size()
    size = @buffer[@read_cursor].ord
    @read_cursor += 1
    if size == 253
      size = _read_num('S', 2)
    elsif size == 254
      size = _read_num('I', 4)
    elsif size == 255
      size = _read_num('Q', 8)
    end
    
    return size
  end
  
  def _read_num(format, size)
    val = @buffer[@read_cursor..@read_cursor+size].unpack(format)
    @read_cursor += size
    return val
  end
  
end


class CoinWallet

  attr_reader :count
  attr_reader :version
  attr_reader :default_key

  def initialize(file, kind)
    @keys = []
    @default_key = nil
    @addressbook = []
    @kinds = Set.new
    @count = 0
    @version = :unknown
    @seed = kind_to_value(kind)

    load_db(file)
  end

  def keys(type = :public)
    return @keys if type.eql? :all

    @addressbook.select {|k| k[:local].eql? true}.collect {|x| x.reject {|v| v == :local}}
  end

  def addressbook(local = nil)
    @addressbook.select {|k| k[:local].eql? local}.collect {|x| x.reject {|v| v == :local}}
  end

  private

  def kind_to_value(kind)
    case kind
      when :bitcoin
        0
      when :litecoin
        48
      when :feathercoin
        14
      when :namecoin
        52
    end
  end

  def load_db(file)
    env = SBDB::Env.new '.', SBDB::CREATE | SBDB::Env::INIT_TRANSACTION
    db = env.btree file, 'main', :flags => SBDB::RDONLY
    @count = db.count

    load_entries(db)

    db.close
    env.close
  end

  def load_entries(db)
    db.each do |k,v|
      tuple = parse_key_value(k, v)
      next unless tuple

      @kinds << tuple[:type]

      case tuple[:type]
        when :version
          @version = tuple[:dump][:version]
        when :defaultkey
          @default_key = tuple[:dump]
        when :key, :wkey, :ckey
          @keys << tuple[:dump]
        when :name
          tuple[:dump][:local] = true if @keys.any? {|k| k[:address].eql? tuple[:dump][:address] }
          @addressbook << tuple[:dump]
      end
    end
  end

  def parse_key_value(key, value)

    kds = BCDataStream.new(key)
    vds = BCDataStream.new(value)
    type = kds.read_string

    hash = {}
    case type
      when 'version'
        hash[:version] = vds.read_uint32()
      when 'name'
        hash[:address] = kds.read_string()
        hash[:name] = vds.read_string()
      when 'defaultkey'
        key = vds.read_bytes(vds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
      when 'key'
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #hash['privkey'] = vds.read_bytes(vds.read_compact_size())
      when "wkey"
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #d['private_key'] = vds.read_bytes(vds.read_compact_size())
        #d['created'] = vds.read_int64()
        #d['expires'] = vds.read_int64()
        #d['comment'] = vds.read_string()
      when "ckey"
        key = kds.read_bytes(kds.read_compact_size)
        #hash[:key] = key
        hash[:address] = B58Encode.public_key_to_bc_address(key, @seed)
        #hash['crypted_key'] = vds.read_bytes(vds.read_compact_size())
    end

    return {type: type.to_sym, dump: hash}
  end

end



puts "dumping..."

cw = CoinWallet.new('ftc_wallet_enc.dat', :feathercoin)

puts "#{cw.count} entries"

puts "Version: #{cw.version}"
puts "Default key: #{cw.default_key}"
puts "Addressbook:"
puts cw.addressbook
puts "Local keys:"
puts cw.keys
