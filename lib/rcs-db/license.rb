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

class NoLicenseError < StandardError
  attr_reader :msg

  def initialize(msg)
    @msg = msg
  end

  def to_s
    @msg
  end
end

class LicenseManager
  include Singleton
  include RCS::Tracer
  include RCS::Crypt

  LICENSE_VERSION = '8.0'
  LICENSE_FILE = 'rcs.lic'

  DONT_STEAL_RCS = "Ò€‹›ﬁﬂ‡°·‚æ…¬˚∆˙©ƒ∂ß´®†¨ˆøΩ≈ç√∫˜µ≤¡™£¢∞§¶•ªº"

  attr_reader :limits

  def initialize
    # default values.
    # you have at least:
    #   - one user to login to the system
    #   - one collector to receive data
    #   - cannot create agents (neither demo nor real)
    @limits = {:type => 'reusable',
               :serial => "off",
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
               :forwarders => false,
               :rmi => [false, false],
               :nia => [0, false],
               :shards => 1,
               :exploits => false,
               :collectors => {:collectors => 1, :anonymizers => 0}}
  end

  def load_license

    # load the license file
    lic_file = File.join Dir.pwd, Config::CONF_DIR, LICENSE_FILE

    if File.exist? lic_file
      trace :info, "Loading license limits #{lic_file}"

      File.open(lic_file, "rb") do |f|
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
    if @limits[:agents][:total] < @limits[:agents][:desktop] or @limits[:agents][:total] < @limits[:agents][:mobile]
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

    @limits[:expiry] = Time.parse(limit[:expiry]).getutc.to_i
    @limits[:maintenance] = Time.parse(limit[:maintenance]).getutc.to_i

    @limits[:users] = limit[:users] if limit[:users] > @limits[:users]

    @limits[:agents][:total] = limit[:agents][:total] if limit[:agents][:total] > @limits[:agents][:total]
    @limits[:agents][:mobile] = limit[:agents][:mobile] if limit[:agents][:mobile] > @limits[:agents][:mobile]
    @limits[:agents][:desktop] = limit[:agents][:desktop] if limit[:agents][:desktop] > @limits[:agents][:desktop]

    @limits[:agents][:windows] = limit[:agents][:windows]
    @limits[:agents][:osx] = limit[:agents][:osx]
    @limits[:agents][:linux] = limit[:agents][:linux]
    @limits[:agents][:winmo] = limit[:agents][:winmo]
    @limits[:agents][:symbian] = limit[:agents][:symbian]
    @limits[:agents][:ios] = limit[:agents][:ios]
    @limits[:agents][:blackberry] = limit[:agents][:blackberry]
    @limits[:agents][:android] = limit[:agents][:android]
    
    @limits[:nia] = limit[:nia]
    @limits[:collectors][:collectors] = limit[:collectors][:collectors] if limit[:collectors][:collectors] > @limits[:collectors][:collectors]
    @limits[:collectors][:anonymizers] = limit[:collectors][:anonymizers] if limit[:collectors][:anonymizers] > @limits[:collectors][:anonymizers]
    
    @limits[:alerting] = true if limit[:alerting] 
    @limits[:correlation] = true if limit[:correlation]
    @limits[:forwarders] = true if limit[:forwarders]
    @limits[:rmi] = limit[:rmi]

    @limits[:shards] = limit[:shards] if limit[:shards] > @limits[:shards]
    @limits[:exploits] = limit[:exploits]
  end

  
  def burn_one_license(type, platform)

    # check if the platform can be used
    unless @limits[:agents][platform][0]
      trace :warn, "You don't have a license for #{platform.to_s}. Queuing..."
      return false
    end

    if @limits[:type] == 'reusable'
      # reusable licenses don't consume any license slot but we have to check
      # the number of already active agents in the db
      desktop = Item.count(conditions: {_kind: 'agent', type: 'desktop', status: 'open'})
      mobile = Item.count(conditions: {_kind: 'agent', type: 'mobile', status: 'open'})
  
      if desktop + mobile >= @limits[:agents][:total]
        trace :warn, "You don't have enough total license to received data. Queuing..."
        return false
      end
      if type == :desktop and desktop < @limits[:agents][:desktop]
        trace :info, "Using a reusable license: #{type.to_s} #{platform.to_s}"
        return true
      end
      if type == :mobile and mobile < @limits[:agents][:mobile]
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

  def can_build_platform(platform, demo)

    # enforce demo flag if not build
    demo = true unless LicenseManager.instance.limits[:agents][platform][0]

    # remove demo flag if not enabled
    demo = false unless LicenseManager.instance.limits[:agents][platform][1]

    # if not build and not demo, raise
    if not LicenseManager.instance.limits[:agents][platform].inject(:|)
      raise NoLicenseError.new("Cannot build #{demo}, NO license")
    end

    return demo
  end

  def check(field)
    # these check are performed just before the creation of an object.
    # thus the comparison is strictly < and not <=
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

      when :injectors
        if Injector.count() < @limits[:nia][0]
          return true
        end

      when :alerting
        return @limits[:alerting]

      when :correlation
        return @limits[:correlation]        

      when :rmi
        return @limits[:rmi]

      when :shards
        if Shard.count() < @limits[:shards]
          return true
        end
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

      if ::Injector.count > @limits[:nia][0]
        trace :fatal, "LICENCE EXCEEDED: Number of injectors is greater than license file. Fixing..."
        # fix by deleting the injector
        offending = ::Injector.first(sort: [[ :updated_at, :desc ]])
        trace :warn, "Deleting injector '#{offending[:name]}' #{offending[:address]}"
        offending.destroy
      end

      if ::Item.count(conditions: {_kind: 'agent', type: 'desktop', status: 'open'}) > @limits[:agents][:desktop]
        trace :fatal, "LICENCE EXCEEDED: Number of agents(desktop) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', type: 'desktop', status: 'open'}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if ::Item.count(conditions: {_kind: 'agent', type: 'mobile', status: 'open'}) > @limits[:agents][:mobile]
        trace :fatal, "LICENCE EXCEEDED: Number of agents(mobile) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', type: 'mobile', status: 'open'}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if ::Item.count(conditions: {_kind: 'agent', status: 'open'}) > @limits[:agents][:total]
        trace :fatal, "LICENCE EXCEEDED: Number of agent(total) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', status: 'open'}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if @limits[:alerting] == false
        trace :fatal, "LICENCE EXCEEDED: Alerting is not enabled in the license file. Fixing..."
        ::Alert.update_all(enabled: false)
      end

      # check if someone modifies manually the items
      ::Item.all.each do |item|
        next if item[:_kind] == 'global'
        if item.cs != item.calculate_checksum
          trace :fatal, "TAMPERED ITEM: [#{item._id}] #{item.name}"
          exit!
        end
      end

    rescue Exception => e
      trace :fatal, "Cannot perform license check: #{e.message}"
    end
  end


  def crypt_check(hash)
    # TODO: remove this for release
    return true
    # calculate the check on the whole hash except the :integrity field itself
    content = hash.reject {|k,v| k == :integrity}.to_s
    # calculate the encrypted SHA1 with magic
    check = aes_encrypt(Digest::SHA1.digest(content), Digest::SHA1.digest("€ ∫∑x=1 ∆t π™")).unpack('H*').first
    # TODO: remove this for release
    #trace :debug, check
    return hash[:integrity] == check
  end


  def counters
    counters = {:users => User.count(conditions: {enabled: true}),
                :agents => {:total => Item.count(conditions: {_kind: 'agent', status: 'open'}),
                               :desktop => Item.count(conditions: {_kind: 'agent', type: 'desktop', status: 'open'}),
                               :mobile => Item.count(conditions: {_kind: 'agent', type: 'mobile', status: 'open'})},
                :collectors => {:collectors => Collector.count(conditions: {type: 'local'}),
                                :anonymizers => Collector.count(conditions: {type: 'remote'})},
                :nia => Injector.count,
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
