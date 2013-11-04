#!/usr/bin/env ruby

require 'optparse'
require 'ffi'
require 'securerandom'
require 'openssl'
require 'digest/sha1'
require 'pp'
require 'yaml'
require 'time'
require 'date'

module Hasp
  extend FFI::Library

  # we can use the HASP dongle only on windows
  if RbConfig::CONFIG['host_os'] =~ /mingw/
    ffi_lib File.join(File.dirname(File.realpath(__FILE__)), 'ruby_x64.dll')

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
  VERSION = 20120504
  KEY = "\xB3\xE0\x2A\x88\x30\x69\x67\xAA\x21\x74\x23\xCC\x90\x99\x0C\x3C"

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

      puts "Error #{info[:error_code]} while communicating with HASP token: #{info[:error_msg]}" unless info[:error_code] == 0

      raise "Cannot find hardware token" if info[:error_code] == ERROR_INFO || info[:error_code] == ERROR_PARSING

      return info
    end

    def time
      time = info[:time]
      raise "Cannot get RTC time" if time == 0
      return time
    rescue Exception => e
      puts "Invalid dongle time, contact support for dongle replacement"
      return Time.now.getutc
    end
  end

end


module LicenseChecker
  extend self

  def load_license(lic_file, version)

    raise "No license file found" unless File.exist? lic_file

    lic = {}

    File.open(lic_file, "rb") do |f|
      lic = YAML.load(f.read)

      # check the authenticity of the license
      unless crypt_check(lic)
        raise 'Invalid License File: corrupted integrity check'
      end

      # the license is not for this version
      if lic[:version] != version
        raise "Invalid License File: incorrect version (#{lic[:version]}) #{version} is needed"
      end

      # use local time if the dongle presence is not enforced
      if lic[:serial] == 'off'
        time = Time.now.getutc
      else
        time = RCS::DB::Dongle.time
      end

      if not lic[:expiry].nil? and Time.parse(lic[:expiry]).getutc < time
        raise "Invalid License File: license expired on #{Time.parse(lic[:expiry]).getutc}"
      end

      if lic[:maintenance].nil?
        raise "Invalid License File: invalid maintenance period"
      end

      if lic[:serial] != 'off'
        puts "Checking for hardware dongle..."
        # get the version from the dongle (can rise exception)
        info = RCS::DB::Dongle.info
        puts "Dongle info: " + info.inspect
        raise "Invalid License File: incorrect serial number (#{lic[:serial]}) #{info[:serial]} is needed" if lic[:serial] != info[:serial]
      else
        puts "Hardware dongle not required..."
      end
    end

    return lic
  end

  def aes_encrypt(clear_text, key, padding = 1)
    cipher = OpenSSL::Cipher::Cipher.new('aes-128-cbc')
    cipher.encrypt
    cipher.padding = padding
    cipher.key = key
    cipher.iv = "\x00" * cipher.iv_len
    edata = cipher.update(clear_text)
    edata << cipher.final
    return edata
  end

  def crypt_check(hash)
    # check the date digest (hidden expiration)
    return false if hash[:digest_seed] and Time.now.to_i > hash[:digest_seed].unpack('I').first

    # first check on signature
    content = hash.reject {|k,v| k == :integrity or k == :signature}.to_s
    check = Digest::HMAC.hexdigest(content, "əɹnʇɐuƃıs ɐ ʇou sı sıɥʇ", Digest::SHA2)
    return false if hash[:signature] != check

    # second check on integrity
    content = hash.reject {|k,v| k == :integrity}.to_s
    check = aes_encrypt(Digest::SHA2.digest(content), Digest::SHA2.digest("€ ∫∑x=1 ∆t π™")).unpack('H*').first
    return false if hash[:integrity] != check

    return true
  end

  # executed from rcs-db-license
  def run!(*argv)
    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-license-check [options]"

      opts.on( '-l', '--license FILE', String, 'Load this license file' ) do |file|
        options[:file] = file
      end

      opts.on( '-v', '--version VERSION', String, 'License file should be this version' ) do |version|
        options[:version] = version
      end

      opts.on( '-i', '--info', 'Check license validity and display info' ) do
        options[:check] = true
      end

      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    raise "No license file specified" unless options[:file]
    raise "No version specified" unless options[:version]

    # load the license
    license = load_license options[:file], options[:version]

    # print the dongle infos
    pp RCS::DB::Dongle.info if license[:serial] != 'off'

    puts "Version: " + license[:version]
    puts "Expiry: " + license[:expiry].to_s

    return 0
  rescue Exception => e
    puts "Cannot load license: #{e.message}"
    #puts e.backtrace.join("\n")
    return 1
  end

end

if __FILE__ == $0
  exit LicenseChecker.run! *ARGV
end