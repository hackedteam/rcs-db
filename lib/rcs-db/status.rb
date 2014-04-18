#
# command line utility to retrieve the status of the system
#

require 'rcs-common/stats'
require 'rcs-common/trace'
require 'colorize'

require 'singleton'

module RCS
module DB

class Status
  include Singleton
  include RCS::Tracer

  def monitor
    components = ::Status.all.sort({status: -1, time: 1})

    puts "System monitoring:\n\n"
    components.each do |comp|
      puts format_component(comp)
    end
  end

  def format_component(component)
    component.name.ljust(25) +
        component.address.ljust(17) +
        Time.at(component.time).to_s.ljust(28) +
        format_status(component.status.to_i) +
        component.info
  end

  def format_status(status)
    return 'OK'.ljust(8).colorize(:green) if status == 0
    return 'WARN'.ljust(8).colorize(:yellow) if status == 1
    return 'ERROR'.ljust(8).colorize(:red) if status == 2
    return 'UNKNOWN'
  end

  def frontend
    collectors = ::Collector.where({type: 'local'}).to_a
    anons = ::Collector.where({type: 'remote'}).to_a

    puts "Frontend topology:\n\n"
    collectors.each do |coll|
      puts "\t#{coll.name} - #{coll.address} (#{coll.internal_address}) - #{coll.version}#{coll.good ? '' : '*'}"
      chain = parse_chain(coll, anons)
      chain.each do |anon|
        puts "\t\t-> #{anon.name} - #{anon.address} - #{anon.version}"
        anons.reject! {|x| x._id == anon._id}
      end
    end

    puts
    puts "Not linked:\n\n"
    anons.each do |anon|
      puts "\t#{anon.name} - #{anon.address} - #{anon.version}"
    end
  end

  def parse_chain(collector, anonymizers)
    chain = []

    # fill the chain with the others
    next_anon = collector[:next].first
    until next_anon.eql? nil
      current = anonymizers.select {|x| x[:_id].to_s.eql? next_anon}.first
      break unless current
      chain << current
      next_anon = current[:next].first
    end

    return chain
  end

  def backend
    shards = Shard.all['shards']

    puts "Backend topology:\n\n"
    shards.each do |shard|
      puts "#{shard['_id']} - #{shard['host']}"
      details = Shard.find(shard['_id'])
      puts "\tCollections: #{details['collections']}\n\tDataSize: #{details['dataSize'].to_s_bytes}\n\tStorage: #{details['storageSize'].to_s_bytes}"
    end
  end

  def run(options)
    # config file parsing
    return 1 unless RCS::DB::Config.instance.load_from_file

    # connect to MongoDB
    return 1 unless RCS::DB::DB.instance.connect

    puts

    # reset upon request
    monitor if options[:system]
    frontend if options[:frontend]
    backend if options[:backend]

    return 0
  end

  # executed from rcs-db-stats
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
      opts.banner = "Usage: rcs-db-status [options]"

      opts.on( '-s', '--system', 'Show the status of all the components (like monitor in the console)' ) do
        options[:system] = true
      end

      opts.on( '-f', '--frontend', 'Show the frontend topology' ) do
        options[:frontend] = true
      end

      opts.on( '-b', '--backend', 'Show the backend topology' ) do
        options[:backend] = true
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the manager
    return Status.instance.run(options)
  end

end

end # Collector
end # RCS

