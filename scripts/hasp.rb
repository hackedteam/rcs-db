#!/usr/bin/env ruby

require 'ffi'
require 'securerandom'
require 'openssl'
require 'digest/sha1'

module Hasp
  extend FFI::Library

	ffi_lib File.join(Dir.pwd, 'bin/hasp-key.dll')

  ffi_convention :stdcall

  AES_PADDING = 16
  STRUCT_SIZE = 272

  class Info < FFI::Struct
    layout :enc, [:char, STRUCT_SIZE+AES_PADDING]
  end

  attach_function :RI, [:pointer], Info.by_value
  attach_function :DC, [], :int

end

class HaspManager

  VERSION = 20111222
  KEY = "\xB3\xE0\x2A\x88\x30\x69\x67\xAA\x21\x74\x23\xCC\x90\x99\x0C\x3C"

  def self.info

    # our info to be returned
    info = {}

    # pick a random IV for the encrypted channel with the DLL
    iv = SecureRandom.random_bytes(16)
    puts "IV: " + iv.unpack('H*').to_s

    # allocate the memory
    ivp = FFI::MemoryPointer.new(:char , 16)
    ivp.write_bytes iv, 0, 16

    # call the actual method in the DLL
    hasp_info = Hasp.RI(ivp)
    enc = hasp_info[:enc].to_ptr.read_bytes Hasp::STRUCT_SIZE + Hasp::AES_PADDING
    puts "RI ENC [#{enc.bytesize}]: " + enc.unpack('H*').to_s
    raise "Invalid ENC size" if enc.bytesize != Hasp::STRUCT_SIZE + Hasp::AES_PADDING

    # decrypt the response with the pre-shared KEY
    decipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    decipher.decrypt
    decipher.padding = 1
    decipher.key = KEY
    decipher.iv = iv
    data = decipher.update(enc)
    data << decipher.final
    puts "DATA [#{data.bytesize}]: " + data.unpack("H*").to_s

    # parse the data
    version = data.slice!(0..3).unpack('I').first
    raise "Invalid HASP version" if version != VERSION
    info[:version] = version

    serial = data.slice!(0..255).delete("\x00")
    info[:serial] = serial

    time = data.slice!(0..7).unpack('Q').first
    time = Time.at(time)
    info[:time] = time

    licenses = data.slice!(0..3).unpack('I').first
    info[:oneshot] = licenses

    return info
  end

  def self.dec
    ret = Hasp.DC
    raise "No license left" unless ret == 1
  end

end

if __FILE__ == $0
  info = HaspManager.info
  puts info.inspect
  puts
  HaspManager.dec
end