#
#  License handling stuff
#

# from RCS::Common
require 'rcs-common/trace'

# system
require 'yaml'
require 'pp'
require 'optparse'

module RCS
module DB

class LicenseManager
  include Singleton
  include RCS::Tracer

  CONF_DIR = 'config'
  LICENSE_FILE = 'rcs.lic'

  attr_reader :limits

  def initialize
    # default values.
    # you have at least:
    #   - one user to login to the system
    #   - one collector to receive data
    #   - as many demo backdoor you want
    @limits = {:type => 'reusable',
               :users => 1,
               :backdoors => {:total => 0,
                              :desktop => 0,
                              :mobile => 0,
                              :windows => false,
                              :osx => false,
                              :linux => false,
                              :winmo => false,
                              :ios => false,
                              :blackberry => false,
                              :symbian => false,
                              :android => false},
               :alerting => false,
               :correlation => false,
               :rmi => false,
               :ipa => 0,
               :collectors => {:collectors => 1, :anonymizers => 0}}
  end

  def load_license
    trace :info, "Loading license limits..."

    version = '8.0'

    #TODO: check the serial of the dongle
    serial = 123

    # load the license file
    lic_file = File.join Dir.pwd, CONF_DIR, LICENSE_FILE

    File.open(lic_file, "r") do |f|
      lic = YAML.load(f.read)
      # TODO: check the crypto signature

      # load only licenses valid for the current dongle' serial and current version
      if lic[:serial] == serial and lic[:version] == version
        add_limits lic
      end
    end

    # sanity check
    if @limits[:backdoors][:total] < @limits[:backdoors][:desktop] or @limits[:backdoors][:total] < @limits[:backdoors][:mobile]
      trace :fatal, 'Invalid License File: total is lower than desktop or mobile'
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

    @limits[:backdoors][:windows] = true if limit[:backdoors][:windows]
    @limits[:backdoors][:osx] = true if limit[:backdoors][:osx]
    @limits[:backdoors][:linux] = true if limit[:backdoors][:linux]
    @limits[:backdoors][:winmo] = true if limit[:backdoors][:winmo]
    @limits[:backdoors][:symbian] = true if limit[:backdoors][:symbian]
    @limits[:backdoors][:ios] = true if limit[:backdoors][:ios]
    @limits[:backdoors][:blackberry] = true if limit[:backdoors][:blackberry]
    @limits[:backdoors][:android] = true if limit[:backdoors][:android]
    
    @limits[:ipa] = limit[:ipa] if limit[:ipa] > @limits[:ipa]
    @limits[:collectors][:collectors] = limit[:collectors][:collectors] if limit[:collectors][:collectors] > @limits[:collectors][:collectors]
    @limits[:collectors][:anonymizers] = limit[:collectors][:anonymizers] if limit[:collectors][:anonymizers] > @limits[:collectors][:anonymizers]
    
    @limits[:alerting] = true if limit[:alerting] 
    @limits[:correlation] = true if limit[:correlation]
    @limits[:rmi] = true if limit[:rmi]
    
  end

  
  def burn_one_license(type)
    #TODO: burn a license forever
    trace :info, "USING A LICENSE FOR:" + type
  end


  def check(field, subfield=nil)
    case (field)
      when :users
        if ::User.count(conditions: {enabled: true}) < @limits[:users]
          return true
        end

      when :backdoors
        desktop = Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'})
        mobile = Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'})

        if desktop + mobile >= @limits[:backdoors][:total]
          return false
        end
        if subfield == :desktop and desktop < @limits[:backdoors][:desktop]
          return true
        end
        if subfield == :mobile and mobile < @limits[:backdoors][:mobile]
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

    # check the consistency of the database (if someone tries to tamper it)

    if User.count(conditions: {enabled: true}) > @limits[:users]
      trace :fatal, "LICENCE EXCEEDED: Number of users is greater than license file. Fixing..."
      # fix by disabling the last updated user
      offending = User.first(conditions: {enabled: true}, sort: [[ :updated_at, :desc ]])
      offending[:enabled] = false
      trace :warn, "Disabling user '#{offending[:name]}'"
      offending.save
    end

    if Collector.count(conditions: {type: 'local'}) > @limits[:collectors][:collectors]
      trace :fatal, "LICENCE EXCEEDED: Number of collector is greater than license file. Fixing..."
      # fix by deleting the collector
      offending = Collector.first(conditions: {type: 'local'}, sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting collector '#{offending[:name]}' #{offending[:address]}"
      offending.destroy
    end
    if Collector.count(conditions: {type: 'remote'}) > @limits[:collectors][:collectors]
      trace :fatal, "LICENCE EXCEEDED: Number of anonymizers is greater than license file. Fixing..."
      # fix by deleting the collector
      offending = Collector.first(conditions: {type: 'remote'}, sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting anonymizer '#{offending[:name]}' #{offending[:address]}"
      offending.destroy
    end

    if Proxy.count > @limits[:ipa]
      trace :fatal, "LICENCE EXCEEDED: Number of proxy is greater than license file. Fixing..."
      # fix by deleting the proxy
      offending = Proxy.first(sort: [[ :updated_at, :desc ]])
      trace :warn, "Deleting proxy '#{offending[:name]}' #{offending[:address]}"
      offending.destroy
    end

    if Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}) > @limits[:backdoors][:desktop]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(desktop) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = Item.first(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

    if Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'}) > @limits[:backdoors][:mobile]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(mobile) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = Item.first(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

    if Item.count(conditions: {_kind: 'backdoor', status: 'open'}) > @limits[:backdoors][:total]
      trace :fatal, "LICENCE EXCEEDED: Number of backdoor(total) is greater than license file. Fixing..."
      # fix by queuing the last updated backdoor
      offending = Item.first(conditions: {_kind: 'backdoor', status: 'open'}, sort: [[ :updated_at, :desc ]])
      offending[:status] = 'queued'
      trace :warn, "Queuing backdoor '#{offending[:name]}' #{offending[:desc]}"
      offending.save
    end

  end

  def counters
    counters = {:users => User.count(conditions: {enabled: true}),
                :backdoors => {:total => Item.count(conditions: {_kind: 'backdoor', status: 'open'}),
                               :desktop => Item.count(conditions: {_kind: 'backdoor', type: 'desktop', status: 'open'}),
                               :mobile => Item.count(conditions: {_kind: 'backdoor', type: 'mobile', status: 'open'})},
                :collectors => {:collectors => Collector.count(conditions: {type: 'local'}),
                                :anonymizers => Collector.count(conditions: {type: 'remote'})},
                :ipa => Proxy.count}

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
