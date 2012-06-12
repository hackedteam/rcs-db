#
# INPUT/OUTPUT statistic manager
#

require 'rcs-common/stats'
require 'rcs-common/trace'

require 'singleton'

module RCS
module Worker

class StatsManager < Stats
  include Singleton
  include RCS::Tracer

  def initialize
    # configure the storage statistics
    @sections = {:minutes => 0, :hours => 60, :days => 24, :weeks => 7}
    @template = {conn: 0, evidence: 0, evidence_size: 0}

    # persist the statistics
    @persist = true

    # where do we save the stats?
    @dump_file = RCS::DB::Config.instance.file('worker_stats')

    # initialize the stats repository
    super

    # load the saved statistics
    @stats = Marshal.load(File.binread(@dump_file)) if File.exist?(@dump_file) && @persist
  end

  def calculate
    trace :debug, "Saving statistics: #{@stats[:minutes][:last].first.inspect}"
    super
    # save the stats in the file
    File.open(@dump_file, 'wb') {|f| f.write Marshal.dump @stats} if @persist
  end

  def purge
    FileUtils.rm_rf(@dump_file)
    initialize
  end

  def print_total
    puts "Total Statistics from: #{@stats[:total][:start]}"

    table_width = 0
    @stats[:total].each_key do |k|
      next if k == :start
      table_width += 18
    end

    table_line = '+' + '-' * (table_width - 1)  + '+'
    puts table_line

    @stats[:total].each_key do |k|
      next if k == :start
      print "| #{k.to_s.center(15)} "
    end
    puts '|'
    puts table_line
    @stats[:total].each_pair do |k,v|
      next if k == :start
      if k.to_s['_size']
        print "| #{v.to_s_bytes.rjust(15)} "
      else
        print "| #{v.to_s.rjust(15)} "
      end
    end
    puts '|'
    puts table_line
  end

  def print_section(section)
    puts "Last 5 #{section.to_s} statistics:"

    table_width = 0
    @stats[:total].each_key do |k|
      next if k == :start
      table_width += 18
    end

    table_line = '+' + '-' * (table_width - 1)  + '+'
    puts table_line

    @stats[section][:last].each do |minute|
      minute.each_pair do |k,v|
        if k.to_s['_size']
          print "| #{v.to_i.to_s_bytes.rjust(15)} "
        else
          print "| #{v.to_s.rjust(15)} "
        end
      end
      puts '|'
    end
    puts table_line
  end

  def print_average(section)
    puts "Average by #{section.to_s} statistics:"

    table_width = 0
    @stats[:total].each_key do |k|
      next if k == :start
      table_width += 18
    end

    table_line = '+' + '-' * (table_width - 1)  + '+'
    puts table_line

    @stats[section][:average].each_pair do |k,v|
      next if k == :samples
      if k.to_s['_size']
        print "| #{v.to_i.to_s_bytes.rjust(15)} "
      else
        print "| #{v.to_s.rjust(15)} "
      end
    end
    puts '|'
    puts table_line

  end


  def run(options)

    # reset upon request
    purge if options[:purge]

    # print the statistics
    print_total

    print_section :weeks
    print_average :weeks
    puts
    print_section :days
    print_average :days
    puts
    print_section :hours
    print_average :hours
    puts
    print_section :minutes
    print_average :minutes

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
      opts.banner = "Usage: rcs-db-stats [options] [instance]"

      opts.on( '-p', '--purge', 'Purge all the stats and restart from ZERO' ) do
        options[:purge] = true
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the manager
    return StatsManager.instance.run(options)
  end

end

end # Collector
end # RCS

