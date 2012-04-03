# encoding: utf-8
#
#  Hardware dongle handling stuff
#

require_relative 'frontend'

# from RCS::Common
require 'rcs-common/trace'

require 'ffi'
require 'securerandom'
require 'openssl'
require 'digest/sha1'

module RCS
module DB

class NoDongleFound < StandardError
  def initialize
    super "NO dongle found, cannot continue"
  end
end

module Hasp
  extend FFI::Library

  # we can use the HASP dongle only on windows
  if RUBY_PLATFORM =~ /mingw/
    ffi_lib File.join(Dir.pwd, 'bin/ruby_x64.dll')

     ffi_convention :stdcall

     AES_PADDING = 16
     STRUCT_SIZE = 272

     class Info < FFI::Struct
       layout :enc, [:char, STRUCT_SIZE + AES_PADDING]
     end

     attach_function :RI, [:pointer], Info.by_value
     attach_function :DC, [], :int
  end

end

class Dongle
  extend RCS::Tracer

  VERSION = 20111222
  KEY = "\xB3\xE0\x2A\x88\x30\x69\x67\xAA\x21\x74\x23\xCC\x90\x99\x0C\x3C"
  DONT_STEAL_RCS = "∆©ƒø†£¢∂øª˚¶∞¨˚˚˙†´ßµ∫√Ïﬁˆ¨Øˆ·‰ﬁÎ¨"

  class << self

    def info

      # fake info for macos
      return {serial: 'off', time: Time.now.getutc, oneshot: 0} if RUBY_PLATFORM =~ /darwin/

      # our info to be returned
      info = {}

      # pick a random IV for the encrypted channel with the DLL
      iv = SecureRandom.random_bytes(16)

      # allocate the memory
      ivp = FFI::MemoryPointer.new(:char , 16)
      ivp.write_bytes iv, 0, 16

      # call the actual method in the DLL
      hasp_info = Hasp.RI(ivp)
      enc = hasp_info[:enc].to_ptr.read_bytes Hasp::STRUCT_SIZE + Hasp::AES_PADDING
      raise "Invalid ENC dongle size: corrupted?" if enc.bytesize != Hasp::STRUCT_SIZE + Hasp::AES_PADDING

      # check if all bytes are zero
      raise "Cannot find hardware dongle" if enc.bytes.collect { |c| c == 0 }.inject(:&)

      # decrypt the response with the pre-shared KEY
      decipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
      decipher.decrypt
      decipher.padding = 1
      decipher.key = KEY
      decipher.iv = iv
      data = decipher.update(enc)
      data << decipher.final

      # parse the data
      version = data.slice!(0..3).unpack('I').first
      raise "Invalid HASP version" if version != VERSION
      info[:version] = version

      serial = data.slice!(0..255).delete("\x00")
      info[:serial] = serial

      time = data.slice!(0..7).unpack('Q').first
      time = Time.at(time).getutc
      info[:time] = time

      licenses = data.slice!(0..3).unpack('I').first
      info[:oneshot] = licenses

      return info
    end

    def decrement
      # no dongle support for macos
      return true if RUBY_PLATFORM =~ /darwin/

      raise "No license left" unless 1 == Hasp.DC
    end

    def time
      return info[:time]
    rescue Exception => e
      trace :debug, "Cannot get time from dongle, falling back"
      return Time.now.getutc
    end
  end

end

end #DB::
end #RCS::
