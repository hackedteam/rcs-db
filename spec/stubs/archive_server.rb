module RCS
  module Stubs
    class ArchiveServer
      def initialize(params = {})
        @address = params[:address] || 'localhost:4449'
        @db_name = params[:db_name] || 'rcs_archive_node'
        @path = File.expand_path(Dir.pwd)
        @config_file = "#{@path}/config/config.yaml"
        @license_file = "#{@path}/config/rcs.lic"
      end

      def run
        return if @thread

        backup(@config_file)
        backup(@license_file)

        # Change the database name and the server port
        File.open(@config_file, 'ab') do |f|
          f.puts "\n"
          f.puts "DB_NAME: #{@db_name}"
          f.puts "LISTENING_PORT: #{@address.split(':').last}"
        end

        # Change the license file, enabling archive mode
        lic_str = File.read(@license_file)
        File.open(@license_file, 'wb') do |f|
          f.write lic_str.gsub('archive: false', 'archive: true')
        end

        # Regenerate license checksums
        system('ruby ./scripts/rcs-db-license-gen.rb -i config/rcs.lic -o config/rcs.lic')

        # Clear the database
        db.drop

        # Launch the application
        @thread = Thread.new { system('./bin/rcs-db TESTARCHIVENODE=1') }

        sleep(14)
      ensure
        restore(@config_file)
        restore(@license_file)
      end

      def kill
        puts "Killing archive node on thread"
        str = `ps aux | grep TESTARCHIVENODE`
        pid = str.split("\n").find { |line| line =~ /ruby/ }.split(" ")[1] rescue nil
        system("kill -9 #{pid}")
      end

      def db
        @db ||= begin
          session = Moped::Session.new([ "127.0.0.1:27017"])
          session.use(@db_name)
          session.with(safe: true)
        end
      end

      def bak(filepath)
        "#{filepath}.bak"
      end

      def backup(filepath)
        FileUtils.cp(filepath, bak(filepath))
      end

      def restore(filename)
        FileUtils.mv(bak(filename), filename) if File.exists?(bak(filename))
      end
    end
  end
end
