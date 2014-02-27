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
require 'rbconfig'

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
  if RbConfig::CONFIG['host_os'] =~ /mingw/
    ffi_lib File.join($execution_directory || Dir.pwd, 'bin/ruby_x64.dll')

    ffi_convention :stdcall

    AES_PADDING = 16
    STRUCT_SIZE = 128

    class Info < FFI::Struct
     layout :enc, [:char, STRUCT_SIZE + AES_PADDING]
    end

    attach_function :RI, [:pointer], Info.by_value
    attach_function :DC, [], :int
  end

end

class Dongle
  extend RCS::Tracer

  VERSION = 20120504
  KEY = "\xB3\xE0\x2A\x88\x30\x69\x67\xAA\x21\x74\x23\xCC\x90\x99\x0C\x3C"
  DONT_STEAL_RCS = "∆©ƒø†£¢∂øª˚¶∞¨˚˚˙†´ßµ∫√Ïﬁˆ¨Øˆ·‰ﬁÎ¨"

	ERROR_INFO = 1
	ERROR_PARSING = 2
	ERROR_LOGIN = 3
	ERROR_RTC = 4
	ERROR_STORAGE = 5

  class << self

    def info

      # fake info for macos
      return {serial: 'off', time: Time.now.getutc, oneshot: 0} if RbConfig::CONFIG['host_os'] =~ /darwin/

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

      info[:serial] = data.slice!(0..31).delete("\x00")

      time = data.slice!(0..7).unpack('Q').first
      time = Time.at(time) unless time == 0
      info[:time] = time

      info[:oneshot] = data.slice!(0..3).unpack('I').first
      info[:error_code] = data.slice!(0..3).unpack('I').first
      info[:error_msg] = data.slice!(0..63).delete("\x00")

      trace :error, "Error #{info[:error_code]} while communicating with HASP token: #{info[:error_msg]}" unless info[:error_code] == 0

      raise "Cannot find hardware token" if info[:error_code] == ERROR_INFO || info[:error_code] == ERROR_PARSING

      return info
    end

    def decrement
      # no dongle support for macos
      return true if RbConfig::CONFIG['host_os'] =~ /darwin/

      raise "No license left" unless 1 == Hasp.DC
    end

    def time
      time = info[:time]
      raise "Cannot get RTC time" if time == 0
      return time
    rescue Exception => e
      trace :warn, "Invalid dongle time, contact support for dongle replacement"
      return Time.now.getutc
    end
  end

end

end #DB::
end #RCS::
