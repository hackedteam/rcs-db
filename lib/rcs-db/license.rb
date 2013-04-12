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

  LICENSE_VERSION = '8.3'

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
               :intelligence => false,
               :connectors => false,
               :rmi => [false, false],
               :nia => [0, false],
               :shards => 1,
               :exploits => false,
               :deletion => false,
               :modify => false,
               :archive => false,
               :scout => true,
               :ocr => true,
               :translation => false,
               :collectors => {:collectors => 1, :anonymizers => 0}}
  end

  def load_license(periodic = false)

    # load the license file
    lic_file = File.join Dir.pwd, Config::CONF_DIR, LICENSE_FILE

    unless File.exist? lic_file
      trace :fatal, "No license file found"
      exit!
    end

    trace :info, "Loading license limits #{lic_file}" unless periodic

    File.open(lic_file, "rb") do |f|
      lic = YAML.load(f.read)

      # check the authenticity of the license
      unless crypt_check(lic)
        trace :fatal, 'Invalid License File: corrupted integrity check'
        exit!
      end

      # the license is not for this version
      if lic[:version] != LICENSE_VERSION
        trace :fatal, 'Invalid License File: incorrect version'
        exit!
      end

      # use local time if the dongle presence is not enforced
      if @limits[:serial] == 'off'
        time = Time.now.getutc
      else
        time = Dongle.time
      end

      if not lic[:expiry].nil? and Time.parse(lic[:expiry]).getutc < time
        trace :fatal, "Invalid License File: license expired on #{Time.parse(lic[:expiry]).getutc}"
        exit!
      end

      # load only licenses valid for the current dongle's serial and current version
      add_limits lic
    end

    # sanity check
    if @limits[:agents][:total] < @limits[:agents][:desktop] or @limits[:agents][:total] < @limits[:agents][:mobile]
      trace :fatal, 'Invalid License File: total is lower than desktop or mobile'
      exit!
    end

    begin
      if @limits[:serial] != 'off'
        trace :info, "Checking for hardware dongle..."
        # get the version from the dongle (can rise exception)
        info = Dongle.info
        trace :info, "Dongle info: " + info.inspect
        raise 'Invalid License File: incorrect serial number' if @limits[:serial] != info[:serial]
        raise 'Cannot read storage from token' if @limits[:type] == 'oneshot' && (info[:error_code] == Dongle::ERROR_LOGIN || info[:error_code] == Dongle::ERROR_STORAGE)
      else
        trace :info, "Hardware dongle not required..." unless periodic
      end
    rescue Exception => e
      trace :fatal, e.message
      exit!
    end

    return true
  end

  def new_license(file)

    raise "file not found" unless File.exist? file

    trace :info, "Loading new license file #{file}"

    content = File.open(file, "rb") {|f| f.read}
    lic = YAML.load(content)

    # check the autenticity of the license
    unless crypt_check(lic)
      raise 'Invalid License File: corrupted integrity check'
    end

    # the license is not for this version
    if lic[:version] != LICENSE_VERSION
      raise 'Invalid License File: incorrect version'
    end

    if lic[:serial] != 'off'
      trace :info, "Checking for hardware dongle..."
      # get the version from the dongle (can rise exception)
      info = Dongle.info
      trace :info, "Dongle info: " + info.inspect
      raise 'Invalid License File: incorrect serial number' if lic[:serial] != info[:serial]
      raise 'Cannot read storage from token' if lic[:type] == 'oneshot' && (info[:error_code] == Dongle::ERROR_LOGIN || info[:error_code] == Dongle::ERROR_STORAGE)
    else
      trace :info, "Hardware dongle not required..."
    end

    # save the new license file
    lic_file = File.join Dir.pwd, Config::CONF_DIR, LICENSE_FILE
    File.open(lic_file, "wb") {|f| f.write content}

    # load the new one
    load_license(true)

    trace :info, "New license file saved"
  end

  def add_limits(limit)

    @limits[:magic] = limit[:check]

    @limits[:type] = limit[:type]
    @limits[:serial] = limit[:serial]

    @limits[:expiry] = limit[:expiry].nil? ? nil : Time.parse(limit[:expiry]).getutc
    @limits[:maintenance] = limit[:maintenance].nil? ? nil : Time.parse(limit[:maintenance]).getutc

    @limits[:users] = limit[:users]

    @limits[:agents][:total] = limit[:agents][:total]
    @limits[:agents][:mobile] = limit[:agents][:mobile]
    @limits[:agents][:desktop] = limit[:agents][:desktop]

    @limits[:agents][:windows] = limit[:agents][:windows]
    @limits[:agents][:osx] = limit[:agents][:osx]
    @limits[:agents][:linux] = limit[:agents][:linux]
    @limits[:agents][:winmo] = limit[:agents][:winmo]
    @limits[:agents][:symbian] = limit[:agents][:symbian]
    @limits[:agents][:ios] = limit[:agents][:ios]
    @limits[:agents][:blackberry] = limit[:agents][:blackberry]
    @limits[:agents][:android] = limit[:agents][:android]
    
    @limits[:collectors][:collectors] = limit[:collectors][:collectors] unless limit[:collectors][:collectors].nil?
    @limits[:collectors][:anonymizers] = limit[:collectors][:anonymizers] unless limit[:collectors][:anonymizers].nil?

    @limits[:nia] = limit[:nia]
    @limits[:rmi] = limit[:rmi]

    @limits[:alerting] = limit[:alerting]
    @limits[:connectors] = limit[:connectors]

    @limits[:shards] = limit[:shards]
    @limits[:exploits] = limit[:exploits]

    @limits[:deletion] = limit[:deletion]
    @limits[:modify] = limit[:modify]

    @limits[:archive] = limit[:archive]

    @limits[:scout] = limit[:scout]

    @limits[:encbits] = limit[:digest_enc]

    @limits[:ocr] = limit[:ocr]
    @limits[:translation] = limit[:translation]
    @limits[:correlation] = limit[:correlation]
    @limits[:intelligence] = limit[:intelligence]

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
      desktop = Item.where(_kind: 'agent', type: 'desktop', status: 'open', demo: false, deleted: false).count
      mobile = Item.where(_kind: 'agent', type: 'mobile', status: 'open', demo: false, deleted: false).count

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
      if Dongle.info[:count] > 0
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
        if ::User.where(enabled: true).count < @limits[:users]
          return true
        end

      when :collectors
        if Collector.where(type: 'local').count < @limits[:collectors][:collectors]
          return true
        end

      when :anonymizers
        if Collector.where(type: 'remote').count < @limits[:collectors][:anonymizers]
          return true
        end

      when :injectors
        if Injector.count < @limits[:nia][0]
          return true
        end

      when :alerting
        return @limits[:alerting]

      when :rmi
        return @limits[:rmi]

      when :exploits
        return @limits[:exploits]

      when :deletion
        return @limits[:deletion]

      when :modify
        return @limits[:modify]

      when :archive
        return @limits[:archive]

      when :scout
        return @limits[:scout]

      when :translation
        return @limits[:translation]

      when :correlation
        return @limits[:correlation]

      when :intelligence
        return @limits[:intelligence]

      when :ocr
        return @limits[:ocr]

      when :shards
        if Shard.count < @limits[:shards]
          return true
        end
    end

    trace :warn, 'LICENCE EXCEEDED: ' + field.to_s
    return false
  end

  def store_in_db
    db = DB.instance.mongo_connection
    db['license'].update({}, @limits, {:upsert  => true})
  end

  def load_from_db
    db = DB.instance.mongo_connection
    db['license'].find({}).first
  end

  def periodic_check
    begin

      # periodically check for license file
      load_license(true)

      # add it to the database so it is accessible to all the components (other than db)
      store_in_db

      # check the consistency of the database (if someone tries to tamper it)
      if ::User.where(enabled: true).count > @limits[:users]
        trace :fatal, "LICENCE EXCEEDED: Number of users is greater than license file. Fixing..."
        # fix by disabling the last updated user
        offending = ::User.first(conditions: {enabled: true}, sort: [[ :updated_at, :desc ]])
        offending[:enabled] = false
        trace :warn, "Disabling user '#{offending[:name]}'"
        offending.save
      end

      if ::Collector.local.count > @limits[:collectors][:collectors]
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
      if ::Collector.remote.count > @limits[:collectors][:anonymizers]
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

      if ::Item.agents.where(type: 'desktop', status: 'open', demo: false, deleted: false).count > @limits[:agents][:desktop]
        trace :fatal, "LICENCE EXCEEDED: Number of agents(desktop) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', type: 'desktop', status: 'open', demo: false}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if ::Item.agents.where(type: 'mobile', status: 'open', demo: false, deleted: false).count > @limits[:agents][:mobile]
        trace :fatal, "LICENCE EXCEEDED: Number of agents(mobile) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', type: 'mobile', status: 'open', demo: false}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if ::Item.agents.where(status: 'open', demo: false, deleted: false).count > @limits[:agents][:total]
        trace :fatal, "LICENCE EXCEEDED: Number of agent(total) is greater than license file. Fixing..."
        # fix by queuing the last updated agent
        offending = ::Item.first(conditions: {_kind: 'agent', status: 'open', demo: false}, sort: [[ :updated_at, :desc ]])
        offending[:status] = 'queued'
        trace :warn, "Queuing agent '#{offending[:name]}' #{offending[:desc]}"
        offending.save
      end

      if @limits[:alerting] == false
        if Alert.count > 0
          trace :fatal, "LICENCE EXCEEDED: Alerting is not enabled in the license file. Fixing..."
          ::Alert.update_all(enabled: false)
        end
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
      #trace :fatal, "Cannot perform license check: #{e.backtrace}"
      exit!
    end
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


  def counters
    counters = {:users => User.where(enabled: true).count,
                :agents => {:total => Item.agents.where(status: 'open', demo: false, deleted: false).count,
                               :desktop => Item.agents.where(type: 'desktop', status: 'open', demo: false, deleted: false).count,
                               :mobile => Item.agents.where(type: 'mobile', status: 'open', demo: false, deleted: false).count},
                :collectors => {:collectors => Collector.local.count,
                                :anonymizers => Collector.remote.count},
                :nia => Injector.count,
                :shards => Shard.count}

    return counters
  end

  def run(options)

    # save the new file if requested
    new_license(options[:new_license]) if options[:new_license]

    # load the license file
    load_license

    # print the current license
    pp Dongle.info if @limits[:serial] != 'off'
    pp @limits

    return 0
  rescue Exception => e
    trace :fatal, "Cannot load license: #{e.message}"
    return 1
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

      opts.on( '-n', '--new FILE', String, 'Load a new license file into the system' ) do |file|
        options[:new_license] = file
      end

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
