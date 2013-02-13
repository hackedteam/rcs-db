#!/usr/bin/env ruby
# encoding: utf-8

require 'singleton'
require 'pp'
require 'optparse'
require 'openssl'

require 'open-uri'
require "net/http"
require "uri"


class Watchdog < Net::HTTPRequest
  METHOD = "WATCHDOG"
  REQUEST_HAS_BODY = false
  RESPONSE_HAS_BODY = false
end

$watermark_table = {'LOuWAplu' => 'devel'}

class Killer
  include Singleton
  
  def request(url, request)
    Timeout::timeout(10) do
      puts "Connecting to: #{url}"
      http = Net::HTTP.new(url, 80)
      http.send_request('WATCHDOG', "#{request}")
    end
  end
  
  def load_from_file(file)
    entries = []
    File.readlines(file).each do |url|
      url = url.strip
      next if url.start_with? "#"
      entries << url
    end
    return entries
  end
  
  def run(options)

    local_address = options[:ip]
    
    unless options[:ip]
      Timeout::timeout(2) do
        local_address = open("http://bot.whatismyipaddress.com") {|f| f.read}
      end
    end
    # check if it's a valid ip address
    raise "Invalid local IP" if /(?:[0-9]{1,3}\.){3}[0-9]{1,3}/.match(local_address).nil?
    
    puts "Local IP: #{local_address}"

    begin
      
      if options[:info]
        collectors = [options[:url]] if options[:url]
        collectors = load_from_file(options[:file]) if options[:file]

        collectors.each do |coll|
          puts
          puts "Requesting info to #{coll}"
          info = request(coll, 'CHECK')
          raise "Bad response, probaly not a collector" unless info.kind_of? Net::HTTPOK
          address, watermark = info.body.split(' ')
          puts "Collector ip address: #{address}"
          puts "Collector watermark: #{watermark} (#{$watermark_table[watermark]})"
        end
      end
      
      if options[:kill]
        collectors = [options[:url]] if options[:url]
        collectors = load_from_file(options[:file]) if options[:file]
        
        collectors.each do |coll|
          puts
          puts "Killing #{coll}"
          ver = request(coll, local_address)
          raise "Bad response, probaly not a collector" unless ver.kind_of? Net::HTTPOK
          raise "Kill command not successful" unless ver.size != 0
          puts "Kill command issued to #{coll} (version: #{ver})"
        end
      end
      
      sleep 1 if options[:loop]
    rescue Interrupt
      puts "User asked to exit. Bye bye!"
      exit!
    rescue Exception => e
      puts "ERROR: #{e.message}"
      #puts "TRACE: " + e.backtrace.join("\n")
    end while options[:loop]
    
  end
  
  def self.run!(*argv)

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rcs-killer [options]"

      opts.on( '-i', '--info URL', String, 'Get info from collector' ) do |url|
        options[:info] = true
        options[:url] = url
      end
      
      opts.on( '-I', '--info-all FILE', String, 'Get info from a list of collectors' ) do |file|
        options[:info] = true
        options[:file] = file
      end
      
      opts.on( '-k', '--kill URL', String, 'Kill the collector' ) do |url|
        options[:kill] = true
        options[:url] = url
      end

      opts.on( '-K', '--kill-all FILE', String, 'Kill a list of collectors' ) do |file|
        options[:kill] = true
        options[:file] = file
      end

      opts.on( '-l', '--loop', 'Loop the requests' ) do
        options[:loop] = true
      end

      opts.on( '-a', '--address IP', String, 'Use this address as source ip' ) do |ip|
        options[:ip] = ip
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
    abort "Don't know what to do..." unless (options[:info] or options[:kill])

    # execute the generator
    return Killer.instance.run(options)
  end

end

if __FILE__ == $0
  Killer.run!(*ARGV)
end