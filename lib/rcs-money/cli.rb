require 'pp'
require 'optparse'
require_relative 'money'

module RCS
  module Money
    module CLI
      extend self

      def run
        options = {}
        optparse = OptionParser.new do |opts|
          opts.banner = "Usage: rcs-money [opts]"

          opts.on('-l', '--list', 'List all supported currencies') {
            list
            exit
          }

          opts.on('-d', '--discover', "Discover the blocks folder on the local system") {
            discover
            exit
          }

          opts.on("-s", '--status', "Show the sync percentage for all the discovered currencies") { |currency|
            status
            exit
          }

          opts.on("-c", '--currency CURRENCY', "Currency name") { |currency|
            options[:currency] = currency.to_sym if currency
          }

          opts.on("-f HASH", '--find', "Find tx by its hash for the specified currency (require -c)") { |tx_hash|
            options[:tx_hash] = tx_hash
          }

          opts.on("-p", '--purge', "Drop database for the specified currency (require -c, can be combined with -i)") {
            options[:purge] = true
          }

          opts.on("-i", '--import', "Import all blkXXXXX.dat files, if any, for the specified currency (require -c, can be combined with -p)") {
            options[:import] = true
          }
        end.parse!

        if options[:tx_hash]
          find(options[:currency], options[:tx_hash])
        elsif options[:purge] and !options[:import]
          purge(options[:currency])
        elsif options[:import]
          import(options[:currency], options)
        end
      end

      def check_currency(currency)
        unless currency
          puts "ERROR: --currency option is required"
          exit
        end

        unless currencies.include?(currency)
          puts "ERROR: Unsupported currency #{currency}"
          exit
        end
      end

      def currencies
        Money::SUPPORTED_CURRENCIES
      end

      def list
        puts "Supported currencies: " + currencies.join(", ")
      end

      def status
        establish_database_connection

        currencies.each do |currency|
          blocks_folder = BlocksFolder.discover(currency)
          percentage = blocks_folder ? "#{blocks_folder.import_percentage}%" : "not found"
          puts "#{currency}:".ljust(16) + "#{percentage}"
        end
      end

      def discover
        puts "Blocks folder on the local system:"

        currencies.each do |currency|
          blocks_folder = BlocksFolder.discover(currency)
          path = blocks_folder ? blocks_folder.path : "not found"
          puts "#{currency}:".ljust(16) + "#{path}"
        end
      end

      def establish_database_connection
        @_conn ||= Application.new.establish_database_connection
      end

      def purge(currency)
        check_currency(currency)
        establish_database_connection
        result = Tx.for(currency).mongo_session.drop
        puts "Drop #{result['dropped'].inspect}: #{result['ok'] == 1.0 ? 'ok' : 'err'}"
      end

      def import(currency, **options)
        check_currency(currency)
        establish_database_connection

        purge(currency) if options[:purge]

        Importer.new(currency, cli: true).run
      end

      def find(currency, hash)
        check_currency(currency)
        establish_database_connection
        tx = Tx.for(currency).find(hash) rescue nil

        if tx
          pp tx.attributes
        else
          puts "ERROR: Unable to find tx #{hash}"
        end
      end
    end
  end
end
