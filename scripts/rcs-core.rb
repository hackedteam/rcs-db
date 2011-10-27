#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'open-uri'
require 'pp'
require 'cgi'
require 'optparse'

class CoreDeveloper

  attr_accessor :name
  
  def login(host, port, user, pass)
    host ||= 'localhost'
    port ||= 4444
    @http = Net::HTTP.new(host, port)
    @http.use_ssl = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    account = { user: user, pass: pass }
    resp = @http.request_post('/auth/login', account.to_json, nil)
    puts "Performing login to #{host}:#{port}"
    puts resp unless resp.kind_of? Net::HTTPSuccess
    @cookie = resp['Set-Cookie'] unless resp['Set-Cookie'].nil?
    puts 
    return @cookie ? true : false
  end

  def logout
    @http.request_post('/auth/logout', nil, {'Cookie' => @cookie})
    puts
    puts "Logged out."
  end

  def list
    puts "List of cores:"
    puts "#{"name".ljust(15)} #{"version".ljust(10)} #{"size".rjust(15)}"
    resp = @http.request_get('/core', {'Cookie' => @cookie})
    list = JSON.parse(resp.body)
    list.each do |core|
      puts "- #{core['name'].ljust(15)} #{core['version'].to_s.ljust(10)} #{core['_grid_size'].to_s.rjust(15)} bytes"
    end
  end

  def get(output)
    puts "Retrieving [#{@name}] core..."
    resp = @http.request_get("/core/#{@name}", {'Cookie' => @cookie})

    if resp.kind_of? Net::HTTPSuccess
      File.open(output, 'wb') {|f| f.write(resp.body)}
      puts "  --> #{output} saved (#{resp.body.bytesize} bytes)"
    else
      raise resp
    end
  end

  def version(version)
    puts "Setting version [#{version}] for [#{@name}] core..."
    @http.request_post("/core/version", {_id: @name, version: version}.to_json, {'Cookie' => @cookie})
  end

  def replace(file)
    content = ''
    File.open(file, 'rb') {|f| content = f.read}
    puts "Replacing [#{@name}] core with new file (#{content.bytesize} bytes)"

    resp = @http.request_post("/core/#{@name}", content, {'Cookie' => @cookie})
    raise resp.body unless resp.kind_of? Net::HTTPSuccess
  end

  def add(file)
    content = ''
    File.open(file, 'rb') {|f| content = f.read}
    puts "Adding [#{file}] to the [#{@name}] core (#{content.bytesize} bytes)"

    resp = @http.request_put("/core/#{@name}?name=#{file}", content, {'Cookie' => @cookie})
    raise resp.body unless resp.kind_of? Net::HTTPSuccess
  end

  def content
    resp = @http.request_get("/core/#{@name}?content=true", {'Cookie' => @cookie})
    raise resp.body unless resp.kind_of? Net::HTTPSuccess
    
    puts "Content of core #{@name}"
    list = JSON.parse(resp.body)
    list.each do |file|
      puts "-> #{file['name'].ljust(20)} #{file['size'].to_s.rjust(15)} bytes  #{file['date'].ljust(15)}"
    end
  end

  def delete
    puts "Deleting [#{@name}] core"
    resp = @http.delete("/core/#{@name}", {'Cookie' => @cookie})
    raise resp.body unless resp.kind_of? Net::HTTPSuccess
  end

  def self.run(options)

    begin
      c = CoreDeveloper.new
      c.name = options[:name]

      if c.name.nil? and (options[:version] or options[:get])
        raise "Must specify a core name"
      end

      raise "Cannot login" unless c.login(options[:db_address], options[:db_port], options[:user], options[:pass])

      c.delete if options[:delete]
      c.replace(options[:replace]) if options[:replace]
      c.add(options[:add]) if options[:add]
      c.content if options[:content]
      c.version(options[:version]) if options[:version]
      c.get(options[:get]) if options[:get]

      # list at the end to reflect changes made by the above operations
      c.list if options[:list]

      raise "not yet implemented" if options[:build]

      c.logout
    rescue Exception => e
      puts "FATAL: #{e.message}"
    end
    
  end

end

# This hash will hold all of the options parsed from the command-line by OptionParser.
options = {}

optparse = OptionParser.new do |opts|
  # Set a banner, displayed at the top of the help screen.
  opts.banner = "Usage: rcs-core [options]"

  opts.separator ""
  opts.separator "Core listing:"
  opts.on( '-l', '--list', 'get the list of cores' ) do
    options[:list] = true
  end

  opts.separator ""
  opts.separator "Core selection:"
  opts.on( '-n', '--name NAME', 'identify the core by it\'s name' ) do |name|
    options[:name] = name
  end

  opts.separator ""
  opts.separator "Core operations:"
  opts.on( '-g', '--get FILE', 'get the core from the db and store it in FILE' ) do |file|
    options[:get] = file
  end
  opts.on( '-r', '--replace CORE', 'replace the core in the db (CORE must be a zip file)' ) do |file|
    options[:replace] = file
  end
  opts.on( '-a', '--add FILE', 'add or replace FILE to the core on the db' ) do |file|
    options[:add] = file
  end
  opts.on( '-c', '--content', 'show the content of a core' ) do 
    options[:content] = true
  end
  opts.on( '-D', '--delete', 'delete the core from the db' ) do
    options[:delete] = true
  end
  opts.on( '-v', '--version VERSION', 'set the version of the core' ) do |version|
    options[:version] = version
  end

  opts.separator ""
  opts.separator "Core building:"
  opts.on( '-b', '--build PARAMS', String, 'build the core with PARAMS' ) do |params|
    options[:build] = params
  end


  opts.separator ""
  opts.separator "Account:"
  opts.on( '-u', '--user USERNAME', String, 'rcs-db username (SYS priv required)' ) do |user|
    options[:user] = user
  end
  opts.on( '-p', '--password PASSWORD', String, 'rcs-db password' ) do |password|
    options[:pass] = password
  end
  opts.on( '-d', '--db-address HOSTNAME', String, 'Use the rcs-db at HOSTNAME' ) do |host|
    options[:db_address] = host
  end
  opts.on( '-P', '--db-port PORT', Integer, 'Connect to tcp/PORT on rcs-db' ) do |port|
    options[:db_port] = port
  end


  opts.separator ""
  opts.separator "General:"
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit!
  end
end

optparse.parse(ARGV)

# execute the configurator
CoreDeveloper.run(options)