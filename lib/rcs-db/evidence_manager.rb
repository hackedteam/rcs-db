# from RCS::Common
require 'rcs-common/trace'

require 'rcs-db/db'
require 'rcs-db/grid'

module RCS
module DB

class EvidenceManager
  include Singleton
  include RCS::Tracer

  SYNC_IDLE = 0
  SYNC_IN_PROGRESS = 1
  SYNC_TIMEOUTED = 2
  SYNC_PROCESSING = 3

  def store_evidence(ident, instance, content)
    return GridFS.put(content, {:filename => "#{ident}_#{instance}"}, "evidence")
  end


  def run(options)

    # setup the trace facility
    RCS::DB::Application.trace_setup

    # config file parsing
    return 1 unless Config.instance.load_from_file

    # connect to MongoDB
    return 1 unless DB.instance.connect

    puts GridFS.get_distinct_filenames "evidence"

    return 0
  end

  # executed from rcs-db-evidence-status
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
      opts.banner = "Usage: rcs-db-evidence-status [options] [instance]"

      opts.on( '-i', '--instance INSTANCE', String, 'Show statistics only for this INSTANCE' ) do |inst|
        options[:instance] = inst
      end

      opts.on( '-p', '--purge', 'Purge all the instance with no pending tasks' ) do
        options[:purge] = true
      end

      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the manager
    return EvidenceManager.instance.run(options)
  end
end # EvidenceDispatcher

end # ::DB
end # ::RCS
