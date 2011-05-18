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
                              :macos => false,
                              :linux => false,
                              :winmo => false,
                              :iphone => false,
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
    @limits[:backdoors][:macos] = true if limit[:backdoors][:macos]
    @limits[:backdoors][:linux] = true if limit[:backdoors][:linux]
    @limits[:backdoors][:winmo] = true if limit[:backdoors][:winmo]
    @limits[:backdoors][:symbian] = true if limit[:backdoors][:symbian]
    @limits[:backdoors][:iphone] = true if limit[:backdoors][:iphone]
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


  def check(field)
    case (field)
      when :users
        if ::User.count(conditions: {enabled: true}) < @limits[:users]
          return true
        end

      when :backdoors
        #TODO: check this
        return false

      when :collectors
        #TODO: check this
        return true

      when :anonymizers
        #TODO: check this
        return true

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
      offending = User.first(sort: [[ :updated_at, :desc ]])
      offending[:enabled] = false
      offending.save
    end

    #TODO: queue out of license backdoors

  end


  def counters
    #TODO: get the real values
    counters = {:users => User.count(conditions: {enabled: true}),
                :backdoors => {:total => 0, :desktop => 0, :mobile => 0},
                :collectors => {:collectors => 1, :anonymizers => 0},
                :ipa => 0}

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
