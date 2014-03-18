require 'rcs-common/trace'
require 'rcs-common/fixnum'
require 'rcs-common/path_utils'

module RCS
module Worker
    class QueueStats
      include RCS::Tracer

      def print_row_line
        table_width = 154
        puts '+' + '-' * table_width + '+'
      end

      def print_header
        puts
        print_row_line
        puts '|' + 'instance'.center(57) + '|' + 'platform'.center(12) + '|' +
             'last sync time'.center(25) + '|' + 'logs'.center(8) + '|' + 'size'.center(13) + '|' + 'shard'.center(34) + '|'
        print_row_line
      end

      def print_footer
        print_row_line
        puts
      end

      def print_rows(shard = nil)
        entries = {}

        session = GridFS.session

        pipeline = [{'$group' => {'_id' => '$filename', 'count' => {'$sum' => 1}, 'size' => {'$sum' => '$length'}}}]

        session['grid.evidence.files'].aggregate(pipeline).each do |doc|
          entries[doc['_id']] = doc.symbolize_keys.reject { |k| k == :_id }
        end

        entries.keys.each do |inst|
          ident = inst.slice(0..13)
          instance = inst.slice(15..-1)
          agent = ::Item.agents.where({ident: ident, instance: instance}).first

          entries[inst][:platform] = agent ? agent[:platform] : '[DELETED]'

          if agent and agent.stat[:last_sync]
            time = Time.at(agent.stat[:last_sync]).getutc
            time = time.to_s.split(' +').first
            entries[inst][:time] = time
          else
            entries[inst][:time] = " "*23
          end
        end

        entries = entries.sort_by {|k,v| v[:time]}

        entries.each do |entry|
          puts "| #{entry[0]} |#{entry[1][:platform].center(12)}| #{entry[1][:time]} |#{entry[1][:count].to_s.rjust(7)} | #{entry[1][:size].to_s_bytes.rjust(11)} | #{shard.rjust(32)} |"
        end
      end

      def self.run!(*argv)
        options = {}

        optparse = OptionParser.new do |opts|
          opts.banner = "Usage: rcs-db-queue [options] "

          opts.on('-h', '--help', 'Display this screen') do
            puts opts
            return 0
          end
        end

        optparse.parse(argv)

        # config file parsing
        return 1 unless RCS::DB::Config.instance.load_from_file

        # connect to MongoDB
        return 1 unless DB.instance.connect

        stats = QueueStats.new
        stats.print_header
        RCS::DB::Shard.hosts.each do |host|
          host = host.split(':').first
          DB.instance.change_mongo_host(host)
          stats.print_rows(host)
        end
        stats.print_footer

        return 0
      end
    end
  end
end
