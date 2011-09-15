# encoding: utf-8
#
#  License handling stuff
#

# relative
require_relative 'dongle.rb'
require_relative 'shard.rb'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/crypt'

# system
require 'yaml'
require 'pp'
require 'optparse'

module RCS
module DB

class LicenseManager
  include Singleton
  include RCS::Tracer
  include RCS::Crypt

  LICENSE_VERSION = '8.0'
  LICENSE_FILE = 'rcs.lic'

  attr_reader :limits

  def initialize
    # default values.
    # you have at least:
    #   - one user to login to the system
    #   - one collector to receive data
    #   - cannot create backdoors (neither demo nor real)
    @limits = {:type => 'reusable',
               :serial => "off",
               :users => 1,
               :backdoors => {:total => 0,
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
               :rmi => false,
               :ipa => 0,
               :shards => 1,
               :collectors => {:collectors => 1, :anonymizers => 0}}
  end

  def load_license

    # load the license file
    lic_file = File.join Dir.pwd, Config::CONF_DIR, LICENSE_FILE

    if File.exist? lic_file
      trace :info, "Loading license limits #{lic_file}"

      File.open(lic_file, "r") do |f|
        lic = YAML.load(f.read)

        # check the autenticity of the license
        unless crypt_check(lic)
          trace :fatal, 'Invalid License File: corrupted integrity check'
          exit
        end

        # the license is not for this version
        if lic[:version] != LICENSE_VERSION
          trace :fatal, 'Invalid License File: incorrect version'
          exit
        end

        if not lic[:expiry].nil? and Time.parse(lic[:expiry]).getutc < Dongle.time
          trace :fatal, "Invalid License File: license expired on #{Time.parse(lic[:expiry]).getutc}"
          exit
        end

        # load only licenses valid for the current dongle's serial and current version
        add_limits lic
      end
    else
      trace :info, "No license file found, starting with default values..."
    end

    # sanity check
    if @limits[:backdoors][:total] < @limits[:backdoors][:desktop] or @limits[:backdoors][:total] < @limits[:backdoors][:mobile]
      trace :fatal, 'Invalid License File: total is lower than desktop or mobile'
      exit
    end

    begin
      if @limits[:serial] != 'off'
        trace :info, "Checking for hardware dongle..."
        # get the version from the dongle (can rise exception)
        if @limits[:serial] != Dongle.serial
          raise 'Invalid License File: incorrect serial number'
        end
      else
        trace :info, "Hardware dongle not required..."
      end
    rescue Exception => e
      trace :fatal, e.message
      exit
    end

    return true
  end

  def add_limits(limit)
    @limits[:type] = limit[:type]
    @limits[:serial] = limit[:serial]

    @limits[:users] = limit[:users] if limit[:users] > @limits[:users]

    @limits[:backdoors][:total] = limit[:backdoors][:total] if limit[:backdoors][:total] > @limits[:backdoors][:total]
    @limits[:backdoors][:mobile] = limit[:backdoors][:mobile] if limit[:backdoors][:mobile] > @limits[:backdoors][:mobile]
    @limits[:backdoors][:desktop] = limit[:backdoors][:desktop] if limit[:backdoors][:desktop] > @limits[:backdoors][:desktop]

    @limits[:backdoors][:windows] = limit[:backdoors][:windows]
    @limits[:backdoors][:osx] = limit[:backdoors][:osx]
    @limits[:backdoors][:linux] = limit[:backdoors][:linux]
    @limits[:backdoors][:winmo] = limit[:backdoors][:winmo]
    @limits[:backdoors][:symbian] = limit[:backdoors][:symbian]
    @limits[:backdoors][:ios] = limit[:backdoors][:ios]
    @limits[:backdoors][:blackberry] = limit[:backdoors][:blackberry]
    @limits[:backdoors][:android] = limit[:backdoors][:android]
    
    @limits[:ipa] = limit[:ipa] if limit[:ipa] > @limits[:ipa]
    @limits[:collectors][:collectors] = limit[:collectors][:collectors] if limit[:collectors][:collectors] > @limits[:collectors][:collectors]
    @limits[:collectors][:anonymizers] = limit[:collectors][:anonymizers] if limit[:collectors][:anonymizers] > @limits[:collectors][:anonymizers]
    
    @limits[:alerting] = true if limit[:alerting] 
    @limits[:correlation] = true if limit[:correlation]
    @limits[:rmi] = true if limit[:rmi]

    @limits[:shards] = limit[:shards] if limit[:shards] > @limits[:shards]
    @limits[:exploits] = limit[:exploits]
  end

  
  def burn_one_license(type, platform)

    # check if the platform can be used
    unless @limits[:backdoors][platform][0]
      trace :warn, "You don't have a license for #{platform.to_s}. Queuing..."
      return false
    end

    if @limits[:type] == 'reusable'
      # reusable licenses don't consume any license slot but we have to check
      # the number of already active backdoors in the db
      desktop = Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'})
      mobile = Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'})
  
      if desktop + mobile >= @limits[:backdoors][:total]
        trace :warn, "You don't have enough total license to received data. Queuing..."
        return false
      end
      if type == :desktop and desktop < @limits[:backdoors][:desktop]
        trace :info, "Using a reusable license: #{type.to_s} #{platform.to_s}"
        return true
      end
      if type == :mobile and mobile < @limits[:backdoors][:mobile]
        trace :info, "Using a reusable license: #{type.to_s} #{platform.to_s}"
        return true
      end

      trace :warn, "You don't have enough license for #{type.to_s}. Queuing..."
      return false
    end

    if @limits[:type] == 'oneshot'

      # do we have available license on the dongle?
      if Dongle.count > 0
        trace :info, "Using a oneshot license: #{type.to_s} #{platform.to_s}"
        Dongle.decrement
        return true
      else
        trace :warn, "You don't have enough license to received data. Queuing..."
        return false
      end
    end

    return false
  end

  def check(field)
    case (field)
      when :users
        if ::User.count(conditions: {enabled: true}) < @limits[:users]
          return true
        end

      when :collectors
        if Collector.count(conditions: {type: 'local'}) < @limits[:collectors][:collectors]
          return true
        end

      when :anonymizers
        if Collector.count(conditions: {type: 'remote'}) < @limits[:collectors][:collectors]
          return true
        end

      when :proxies
        if Proxy.count() < @limits[:ipa]
          return true
        end

      when :alerting
        return @limits[:alerting]

      when :correlation
        return @limits[:correlation]        

      when :rmi
        return @limits[:rmi]

    end

    trace :warn, 'LICENCE EXCEEDED: ' + field.to_s
    return false
  end


  def periodic_check

    # get the serial of the dongle.
    # this will raise an exception if the dongle is not found
    # we have to stop the process in this case
    Dongle.serial

    begin
    # check the consistency of the database (if someone tries to tamper it)
    if ::User.count(conditions: {enabled: true}) > @limits[:users]
      trace :fatal, "LICENCE EXCEEDED: Number of users is greater than license file. Fixing..."
      # fix by disabling the last updated user
      offending = ::User.first(conditions: {enabled: true}, sort: [[ :updated_at, :desc ]])
      offending[:enabled] = false
      trace :warn, "Disabling user '#{offending[:name]}'"
      offending.save
    end

    if ::Collector.count(conditions: {type: 'local'}) > @limits[:collectors][:collectors]
      trace :fatal, "LICENCE EXCEEDED: Number of collector is greater than license file. Fixing..."
      # fix by deleting the collector
      offending = ::Collector.first(conditions: {type: 'local'}, sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting collector '#{offending[:name]}' #{offending[:address]}"
      # clear the chain of (possible) anonymizers
      next_id = offending['next'][0]
      begin
        break if next_id.nil?
        curr = ::Collector.find(next_id) 
        trace :warn, "Fixing the anonymizer chain: #{curr['name']}"
        next_id = curr['next'][0]
        curr.prev = [nil]
        curr.next = [nil]
        curr.save
      end until next_id.nil?
      offending.destroy
    end
    if ::Collector.count(conditions: {type: 'remote'}) > @limits[:collectors][:anonymizers]
      trace :fatal, "LICENCE EXCEEDED: Number of anonymizers is greater than license file. Fixing..."
      # fix by deleting the collector
      offending = ::Collector.first(conditions: {type: 'remote'}, sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting anonymizer '#{offending[:name]}' #{offending[:address]}"
      offending.destroy
    end

    if ::Proxy.count > @limits[:ipa]
      trace :fatal, "LICENCE EXCEEDED: Number of proxy is greater than license file. Fixing..."
      # fix by deleting the proxy
      offending = ::Proxy.first(sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting proxy '#{offending[:name]}' #{offending[:address]}"
      offending.destroy
    end

    if ::Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}) > @limits[:backdoors][:desktop]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(desktop) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = ::Item.first(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

    if ::Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'}) > @limits[:backdoors][:mobile]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(mobile) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = ::Item.first(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

    if ::Item.count(conditions: {_kind: 'backdoor', status: 'open'}) > @limits[:backdoors][:total]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(total) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = ::Item.first(conditions: {_kind: 'backdoor', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

    if @limits[:alerting] == false
      trace :fatal, "LICENCE EXCEEDED: Alerting is not enabled in the license file. Fixing..."
      ::Alert.update_all(enabled: false)
    end
    rescue Exception => e
      trace :fatal, "Cannot perform license check: #{e.message}"
    end
  end


  def crypt_check(hash)
    # calculate the check on the whole hash except the :integrity field itself
    content = hash.reject {|k,v| k == :integrity}.to_s
    # calculate the encrypted SHA1
    check = aes_encrypt(Digest::SHA1.digest(content), Digest::SHA1.digest("€ ∫∑x=1 ∆t π™")).unpack('H*').first
    #trace :debug, check
    return hash[:integrity] == check
  end


  def counters
    counters = {:users => User.count(conditions: {enabled: true}),
                :backdoors => {:total => Item.count(conditions: {_kind: 'backdoor', status: 'open'}),
                               :desktop => Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}),
                               :mobile => Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'})},
                :collectors => {:collectors => Collector.count(conditions: {type: 'local'}),
                                :anonymizers => Collector.count(conditions: {type: 'remote'})},
                :ipa => Proxy.count,
                :shards => Shard.count}

    return counters
  end

  def run(options)
    # load the license file
    load_license

    pp @limits

    return 0
  end

  # executed from rcs-db-license
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def trace(level, message)
        puts message
      end
    end

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-db-license [options]"

      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the configurator
    return LicenseManager.instance.run(options)
  end

end

end #DB::
end #RCS::
