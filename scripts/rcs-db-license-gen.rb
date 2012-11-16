#!/usr/bin/env ruby
# encoding: utf-8

require 'singleton'
require 'yaml'
require 'pp'
require 'optparse'
require 'securerandom'
require 'openssl'
require 'digest/sha1'
require 'time'

class LicenseGenerator
  include Singleton

  LICENSE_VERSION = '8.3'

  def initialize
    # default values.
    # you have at least:
    #   - one user to login to the system
    #   - one collector to receive data
    #   - cannot create agents (neither demo nor real)
    @limits = {:type => 'reusable',
               :serial => "off",
               :version => LICENSE_VERSION,
               :users => 1,
               :agents => {:total => 0,
                            :desktop => 0,
                            :mobile => 0,
                            :windows => [false, false],
                            :osx => [false, false],
                            :linux => [false, false],
                            :winmo => [false, false],
                            :ios => [false, false],
                            :blackberry => [false, false],
                            :symbian => [false, false],
                            :android => [false, false]},
               :alerting => false,
               :correlation => false,
               :connectors => false,
               :rmi => [false, false],
               :nia => [0, false],
               :shards => 1,
               :exploits => false,
               :deletion => false,
               :scout => true,
               :ocr => true,
               :translate => false,
               :collectors => {:collectors => 1, :anonymizers => 0},
               :check => SecureRandom.urlsafe_base64(8).slice(0..7)
    }
  end

  def load_license_file(file)
    File.open(file, "rb") {|f| @limits = YAML.load(f.read)}
  end

  def save_license_file(file)
    File.open(file, 'wb') {|f| f.write @limits.to_yaml}
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

  def calculate_integrity(values)
    puts "Recalculating integrity..."

    # remove the integrity itself to exclude it from the digest
    values.delete :integrity
    values.delete :signature

    # this is totally fake, just to disguise someone reading the license file
    values[:digest] = SecureRandom.hex(20)

    # this is totally fake, just to disguise someone reading the license file
    values[:signature] = Digest::HMAC.hexdigest(values.to_s, "əɹnʇɐuƃıs ɐ ʇou sı sıɥʇ", Digest::SHA2)

    # this is the real integrity check
    values[:integrity] = aes_encrypt(Digest::SHA2.digest(values.to_s), Digest::SHA2.digest("€ ∫∑x=1 ∆t π™")).unpack('H*').first
  end

  def check_integrity(values)
    puts "Checking integrity..."

    # the license is not for this version
    if values[:version] != LICENSE_VERSION
      puts "Invalid License File: version is not #{LICENSE_VERSION}, fixing it..."
      values[:version] = LICENSE_VERSION
    end

    # wrong date
    if not values[:expiry].nil? and Time.parse(values[:expiry]).getutc < Time.now.getutc
      abort "Invalid License File: license expired on #{Time.parse(values[:expiry]).getutc}"
    else
      puts "Expiration date: #{values[:expiry]}"
    end

    # sanity check
    if values[:agents][:total] < values[:agents][:desktop] or values[:agents][:total] < values[:agents][:mobile]
      abort 'Invalid License File: total is lower than desktop or mobile'
    end

    if values[:serial] == 'off'
      puts "The license will NOT ask for a HASP dongle"
    else
      puts "The HASP dongle associated with this license is #{values[:serial]}"
    end

    # first check on signature
    content = values.reject {|k,v| k == :integrity or k == :signature}.to_s
    if RUBY_PLATFORM =~ /java/
      check = OpenSSL::HMAC.hexdigest(Digest::SHA2, "əɹnʇɐuƃıs ɐ ʇou sı sıɥʇ", content)
    else
      check = Digest::HMAC.hexdigest(content, "əɹnʇɐuƃıs ɐ ʇou sı sıɥʇ", Digest::SHA2)
    end

    puts "Signature is NOT valid." if values[:signature] != check

    # second check on integrity
    content = values.reject {|k,v| k == :integrity}.to_s
    check = aes_encrypt(Digest::SHA2.digest(content), Digest::SHA2.digest("€ ∫∑x=1 ∆t π™")).unpack('H*').first
    puts "Integrity is NOT valid." if values[:integrity] != check

  end

  def run(options)

    # load the input file
    if options[:input]
      load_license_file options[:input]
    end

    # add the watermark if not already present
    @limits[:check] = SecureRandom.urlsafe_base64(8).slice(0..7) unless @limits[:check]

    # check if the input file is valid
    check_integrity @limits

    # the real stuff is here
    calculate_integrity @limits

    # write the output file
    if options[:output]
      save_license_file options[:output]
      puts "License file created. #{File.size(options[:output])} bytes"
    end

    pp @limits if options[:verbose]

  end

  # executed from rcs-db-license
  def self.run!(*argv)

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-db-license-gen [options]"

      opts.on( '-g', '--generate', 'Generate a new license template' ) do
        options[:gen] = true
      end

      opts.on( '-i', '--input FILE', String, 'Input license file (will be fixed if corrupted)' ) do |file|
        options[:input] = file
      end

      opts.on( '-o', '--output FILE', String, 'Output license file' ) do |file|
        options[:output] = file
      end

      opts.on( '-v', '--verbose', 'Verbose mode' ) do
        options[:verbose] = true
      end

      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    # do the magic parsing
    optparse.parse(argv)

    # error checking
    abort "Don't know what to do..." unless (options[:gen] or options[:input])
    abort "No output file specified" unless options[:output]

    # execute the generator
    return LicenseGenerator.instance.run(options)
  end

end

if __FILE__ == $0
  LicenseGenerator.run!(*ARGV)
end
