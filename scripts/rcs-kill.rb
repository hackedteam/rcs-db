#!/usr/bin/env ruby
# encoding: utf-8

require 'singleton'
require 'pp'
require 'optparse'
require 'openssl'

require 'open-uri'
require "net/http"
require "uri"

$watermark_table = {"B3lZ3bup" => "VIRGIN",
  "q6OVLjoD"=>"afp",
  "paEr6KlM"=>"alfahad-prod",
  "MBe5kSWG"=>"alfahad-test",
  "HXcMQKsB"=>"ati",
  'CscR5f7w'=>"azns",
  "fsPcaLii"=>"azure",
  "JZfKkrNd"=>'bsgo',
  "p8DQ8ZjQ"=>"bull",
  'ev68E732'=>'cba',
  "00yRHOTA"=>"cni-old",
  "XTqDh8yF"=>"cni-prod",
  "hC37bvu2"=>"cni-test",
  "7UBPM2tM"=>"csdn",
  "JBq6sMVX"=>"csh-pa",
  "XidiPq2M"=>"csh-vr",
  "2ZaXtINx"=>"cusaem",
  "30UN7R0l"=>"demo1",
  "q4afkQWr"=>"devel",
  "GDWwVyrq"=>"dod",
  'Kwh80g9E'=>'eqd',
  'Xt1DW33K'=>'fae-demo',
  'U5vL9XXh'=>'fae-trial',
  'j84fj1Ej'=>'gedp',
  "vIByzgbS"=>"gip",
  "KY4pBxoC"=>"gnse",
  "nFGPKB8T"=>"ida-prod",
  "HtAUfHdq"=>"ida-test",
  "74FFGHrh"=>"insa",
  "45u8wvtB"=>"intech-condor",
  "d4vofCKS"=>"intech-falcon",
  "NO7Sy8tl"=>"intech-trial",
  "hr2Sdm23"=>"katie",
  "j4Dnq4lY"=>"knb",
  'whP1Z114'=>'kvant',
  "ZgLs9Knj"=>"macc",
  "De3elpjn"=>"mcdf",
  "hr$ddKc0"=>"mimy",
  "rMMNNu0g"=>"mkih",
  '169hWMEj'=>'moaca',
  "069sWhEj"=>"moi",
  "NnkL7M2C"=>"mxnv",
  "h2zYJ264"=>"niss-01",
  "GErh2CTQ"=>"niss-02",
  "B4y9gjKB"=>"nss",
  "PxL2BITH"=>"orf",
  "WksS4Fba"=>"panp",
  "yIQVWBIW"=>"pcit",
  "f7Ch9Y1H"=>"pf",
  "kjmljtaV"=>"pgj",
  "Xn6PbS3f"=>"phoebe-prod",
  "an5GeV3M"=>"phoebe-test",
  "25GSdf2h"=>"phoebe-demo",
  'AIQ6WcIW'=>'pmo',
  "kJ3kVZXU"=>"pn",
  "4qXth8Sd"=>"pp",
  "HBsxPyXs"=>"pp-8",
  "Q0BnNWlg"=>"rcmp",
  "8hbGc5FW"=>"rcs-demo",
  "tMkD7I7H"=>"rcs-test",
  "UjEpdaZw"=>"rcs-trial-01",
  "wkVoFkAT"=>"rcs-trial-02",
  "QYkYTGxQ"=>"rcs-trial-03",
  "PMc9ux2v"=>"rcs-trial-04",
  "Czu9PEbg"=>"rcs-trial-05",
  "9RDKyUOg"=>"rcs-trial-06",
  "AATHaG4q"=>"rcs-trial-07",
  "VSAO1uA0"=>"rcs-trial-08",
  "fDlKdSxH"=>"rcs-trial-algeria",
  "5P77pcBK"=>"rcs-trial-bin",
  "vs1tUVQR"=>"rcs-trial-bsd",
  "ZwQYmhgx"=>"rcs-trial-fajar",
  "251zfDbu"=>"rcs-trial-farin",
  "Fiw5Th3z"=>"rcs-trial-indo",
  "VNVj9Fkq"=>"rcs-trial-mns",
  "reQsJlwa"=>"rcs-trial-nice",
  "ioMsWQzR"=>"rcs-trial-pcs",
  "NxdP6SRp"=>"rcs-trial-rs",
  "mERh04Tk"=>"rcs-trial-starlight",
  "DC9RWNCC"=>"rcs-trial-vba",
  "B16S0SHJ"=>"rcsspa",
  "s4twpefL"=>"robotec-a",
  'j6dQqpsj'=>'ros',
  'igGf3d1j'=>'sduc',
  "lBhEn16q"=>"segob",
  "KdQdJeaC"=>"sio-prod",
  "ebXMHVBX"=>"sio-test",
  "WCOUQarb"=>"ska",
  "Xuu5XSXT"=>"ssns",
  "M8GQZoCE"=>"tcc-gid",
  'Ra6jeeCa'=>'thdoc',
  "ZjvOuN3m"=>"tnp",
  "wHvPBn7c"=>"trial-dc",
  "Sg96gC96"=>"uaeaf",
  "ZY4eyq9p"=>"uzc",
  'LOuWAplu'=>'devel'}

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

  def analyze_scout_v1(sample)
    # Click to start the program
    marker = "\x43\x00\x6C\x00\x69\x00\x63\x00\x6B\x00\x20\x00\x74\x00\x6F\x00\x20\x00\x73\x00\x74\x00\x61\x00\x72\x00\x74\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x70\x00\x72\x00\x6F\x00\x67\x00\x72\x00\x61\x00\x6D\x00\x00\x00\x00\x00" 
    offset = sample.index(marker) 
    raise "marker for watermark not found" unless offset
    offset += marker.size + 28
    watermark = sample[offset..offset+7]
    puts "WATERMARK: #{watermark} (#{$watermark_table[watermark]})"
    
    # Compositionimage/jpeg
    marker = "\x43\x00\x6F\x00\x6D\x00\x70\x00\x6F\x00\x73\x00\x69\x00\x74\x00\x69\x00\x6F\x00\x6E\x00\x00\x00\x69\x00\x6D\x00\x61\x00\x67\x00\x65\x00\x2F\x00\x6A\x00\x70\x00\x65\x00\x67\x00\x00\x00\x00\x00"
    offset = sample.index(marker) 
    raise "marker for ident not found" unless offset
    offset += marker.size + 12
    ident = sample[offset..offset+14]
    ident[0..3] = "RCS_"
    puts "IDENT: " + ident
    
    # UNKNOWN\.tmp
    marker = "\x55\x00\x4E\x00\x4B\x00\x4E\x00\x4F\x00\x57\x00\x4E\x00\x00\x00\x00\x00\x00\x00\x5C\x00\x00\x00\x2E\x00\x74\x00\x6D\x00\x70\x00\x00\x00\x00\x00"
    offset = sample.index(marker) 
    raise "marker for sync not found" unless offset
    offset += marker.size + 40
    sync = sample[offset..offset+63]
    puts "SYNC ADDRESS: " + sync
  end
  
  def analyze_scout_v2(sample)
    # Click to start the program
    marker = "\x43\x00\x6C\x00\x69\x00\x63\x00\x6B\x00\x20\x00\x74\x00\x6F\x00\x20\x00\x73\x00\x74\x00\x61\x00\x72\x00\x74\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x70\x00\x72\x00\x6F\x00\x67\x00\x72\x00\x61\x00\x6D\x00\x00\x00\x00\x00" 
    offset = sample.index(marker) 
    raise "marker for watermark not found" unless offset
    offset += marker.size + 28
    watermark = sample[offset..offset+7]
    puts "WATERMARK: #{watermark} (#{$watermark_table[watermark]})"
    
    # ExitProcesskernel32
    marker = "\x45\x78\x69\x74\x50\x72\x6F\x63\x65\x73\x73\x00\x6B\x00\x65\x00\x72\x00\x6E\x00\x65\x00\x6C\x00\x33\x00\x32\x00\x00\x00\x00\x00" 
    offset = sample.index(marker) 
    raise "marker for ident not found" unless offset
    offset += marker.size
    ident = sample[offset..offset+14]
    ident[0..3] = "RCS_"
    puts "IDENT: " + ident
    
    # %s\%s.tmp
    marker = "\x25\x00\x73\x00\x5C\x00\x25\x00\x73\x00\x2E\x00\x74\x00\x6D\x00\x70\x00\x00\x00"
    offset = sample.index(marker) 
    raise "marker for sync not found" unless offset
    offset += marker.size
    sync = sample[offset..offset+63]
    puts "SYNC ADDRESS: " + sync
  end

  def analyze_scout_v3(sample)
    # Click to start the program
    marker = "\x43\x00\x6C\x00\x69\x00\x63\x00\x6B\x00\x20\x00\x74\x00\x6F\x00\x20\x00\x73\x00\x74\x00\x61\x00\x72\x00\x74\x00\x20\x00\x74\x00\x68\x00\x65\x00\x20\x00\x70\x00\x72\x00\x6F\x00\x67\x00\x72\x00\x61\x00\x6D\x00\x00\x00\x00\x00"
    offset = sample.index(marker)
    raise "marker for watermark not found" unless offset
    offset += marker.size + 28
    watermark = sample[offset..offset+7]
    puts "WATERMARK: #{watermark} (#{$watermark_table[watermark]})"

    # ExitProcess
    marker = "\x45\x78\x69\x74\x50\x72\x6F\x63\x65\x73\x73\x00\x00\x00\x00\x00"
    offset = sample.index(marker)
    raise "marker for ident not found" unless offset
    offset += marker.size
    ident = sample[offset..offset+14]
    ident[0..3] = "RCS_"
    puts "IDENT: " + ident

    # elitescoutrecover
    marker = "\x65\x00\x6C\x00\x69\x00\x74\x00\x65\x00\x00\x00\x73\x00\x63\x00\x6F\x00\x75\x00\x74\x00\x00\x00\x72\x00\x65\x00\x63\x00\x6F\x00\x76\x00\x65\x00\x72\x00\x00\x00\x00\x00\x00\x00"
    offset = sample.index(marker)
    raise "marker for sync not found" unless offset
    offset += marker.size
    sync = sample[offset..offset+63]
    puts "SYNC ADDRESS: " + sync
  end

  def analyze_scout_v5(sample)
    offset = 0x2E6E4
    watermark = sample[offset..offset+7]
    puts "WATERMARK: #{watermark} (#{$watermark_table[watermark]})"

    offset = 0x2e4d0
    ident = sample[offset..offset+14]
    ident[0..3] = "RCS_"
    puts "IDENT: " + ident

    offset = 0x2E7C0
    sync = sample[offset..offset+63]
    puts "SYNC ADDRESS: " + sync
  end

  def analyze_scout_v51(sample)
    offset = 0x2e724
    watermark = sample[offset..offset+7]
    puts "WATERMARK: #{watermark} (#{$watermark_table[watermark]})"

    offset = 0x2e510
    ident = sample[offset..offset+14]
    ident[0..3] = "RCS_"
    puts "IDENT: " + ident

    offset = 0x2e800
    sync = sample[offset..offset+63]
    puts "SYNC ADDRESS: " + sync
  end

  def analyze_unknown(sample)
    offset = nil
    $watermark_table.keys.each do |k|
      offset = sample.index(k)
      if offset
        puts "WATERMARK: #{k} (#{$watermark_table[k]})"
        break
      end
    end
    if offset
      # heuristic (completely unreliable) to find the ident...
      ident = sample.index('0000')
      return unless ident
      ident = sample[ident..ident+11].to_i
      puts "IDENT: RCS_" + ident.to_s.rjust(10, '0') unless ident == 0
    else
      puts "No known watermark found!"
    end
  end

  def compare_offset(binary, offset, value)
    version = binary[offset..offset+3]
    return false if version.nil?
    version = version.unpack('I').first
    version == value
  end

  def detect_version(binary)
    return 1 if compare_offset(binary, 0x20714, 1)
    return 2 if compare_offset(binary, 0x20868, 2)
    return 3 if compare_offset(binary, 0x21518, 3)
    return 5 if compare_offset(binary, 0x21956, 5)
    return 5.1 if compare_offset(binary, 0x21946, 5)

    return "unknown"
  end

  def analyze(file)
    sample = File.binread(file)
    version = detect_version(sample)
    puts "SCOUT VERSION: #{version}" #if version.is_a? Fixnum

    case(version)
      when 1
        analyze_scout_v1(sample)
      when 2
        analyze_scout_v2(sample)
      when 3
        analyze_scout_v3(sample)
      when 5
        analyze_scout_v5(sample)
      when 5.1
        analyze_scout_v51(sample)
      when 6
        analyze_scout_v6(sample)
      when 7
        analyze_scout_v7(sample)
      else
        puts "UNKNOWN BINARY, falling back to grep..."
        analyze_unknown(sample)
    end

  end

  def check_collector(url)
    puts
    puts "Checking reply of #{url}"
    http = Net::HTTP.new(url, 80)
    resp = http.send_request('GET', "/")
    raise "No response, probably down" unless resp.kind_of? Net::HTTPResponse
    puts "#{url} replied with #{resp.class}..."
    puts resp.body.inspect
  end

  def get_collector_info(url)
    puts
    puts "Requesting info to #{url}"
    info = request(url, 'CHECK')
    raise "Cannot get info, unsupported command by collector" unless info.kind_of? Net::HTTPOK
    address, watermark = info.body.split(' ')
    # we don't have the collector address
    if watermark.nil?
      watermark = address.dup
      address = 'unknown'
    end
    puts "Collector ip address: #{address}"
    puts "Collector watermark: #{watermark} (#{$watermark_table[watermark]})"

    puts
    puts "Requesting SSL info to #{url}"
    ssl_info = get_ssl_info(url, 443)
    pp ssl_info
  end

  def get_ssl_info(url, port)
    tcp_client = TCPSocket.new url, port
    ssl_client = OpenSSL::SSL::SSLSocket.new tcp_client
    ssl_client.connect
    cert = OpenSSL::X509::Certificate.new(ssl_client.peer_cert)
    ssl_client.sysclose
    tcp_client.close

    info = {}

    info[:issuer] = OpenSSL::X509::Name.new(cert.issuer).to_a
    info[:subject] = OpenSSL::X509::Name.new(cert.subject).to_a
    info[:valid_on] = cert.not_before
    info[:valid_until] = cert.not_after

    info
  end

  def kill_collector(url)
    puts
    puts "Killing #{url}"
    ver = request(url, $local_address)
    raise "Bad response, probably not a collector" unless ver.kind_of? Net::HTTPOK
    raise "Kill command not successful" unless ver.size != 0
    puts "Kill command issued to #{url} (version: #{ver.body})"
  end

  def run(options)

    return analyze(options[:analyze]) if options[:analyze]

    $local_address = options[:ip]
    
    unless options[:ip]
      Timeout::timeout(2) do
        $local_address = open("http://bot.whatismyipaddress.com") {|f| f.read}
      end
    end
    # check if it's a valid ip address
    raise "Invalid local IP" if /(?:[0-9]{1,3}\.){3}[0-9]{1,3}/.match($local_address).nil?
    
    puts "Local IP: #{$local_address}"

    begin
      begin
        collectors = [options[:url]] if options[:url]
        collectors = load_from_file(options[:file]) if options[:file]

        if options[:check]
          collectors.each { |coll| check_collector(coll) }
        end

        if options[:info]
          collectors.each { |coll| get_collector_info(coll) }
        end

        if options[:kill]
          collectors.each { |coll| kill_collector(coll) }
        end

        sleep 1 if options[:loop]
      rescue Interrupt
        puts "User asked to exit. Bye bye!"
        exit!
      rescue Exception => e
        puts "ERROR: #{e.message}"
      end

    end while options[:loop]

  rescue Interrupt
    puts "User asked to exit. Bye bye!"
    exit!
  rescue Exception => e
    puts "ERROR: #{e.message}"
    #puts "TRACE: " + e.backtrace.join("\n")
  end
  
  def self.run!(*argv)

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rcs-killer [options]"

      opts.separator ""
      opts.separator "Collector options:"
      opts.on( '-c', '--check URL', String, 'Check if the collector is up and running' ) do |url|
        options[:check] = true
        options[:url] = url
      end

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

      opts.separator ""
      opts.separator "Leaked samples:"
      opts.on( '-A', '--analyze FILE', String, 'Get info from a leaked agent' ) do |file|
        options[:analyze] = file
      end

      opts.separator ""
      opts.separator "General options:"
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
    abort "Don't know what to do..." unless (options[:info] or options[:check] or options[:kill] or options[:analyze])

    # execute the generator
    return Killer.instance.run(options)
  end

end

if __FILE__ == $0
  Killer.run!(*ARGV)
end