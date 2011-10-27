#
#  Cores handling module
#
require_relative 'db_layer'
require_relative 'grid'

# from RCS::Common
require 'rcs-common/trace'

# system
require 'optparse'

module RCS
module DB

class Core
  extend RCS::Tracer

  def self.run(options)

    # make sure we have a connection to the DB
    DB.instance.connect
    
    if options[:list]
      trace :info, "List of available cores: "
      ::Core.all.each do |core|
        file = GridFS.get core[:_grid].first
        trace :info, "#{core.name.ljust(15)} #{core.version.to_s.ljust(10)} #{file.file_length.to_s.rjust(15)} bytes"
      end
    end

    if options[:put]
      # split the argument list
      # the format is:  name,version,file
      args = options[:put].split(',')

      # make sure to delete the old one
      core = ::Core.where({platform: args[0], name: args[1]}).first
      unless core.nil?
        GridFS.delete core[:_grid].first
        core.destroy
      end

      # save the new core
      nc = ::Core.new
      nc[:name] = args[0]
      nc[:version] = args[1]

      if File.exist?(args[2]) and File.file?(args[2])
        content = File.open(args[2], 'rb') {|f| f.read}
      else
        trace :fatal, "Cannot open file: #{args[2]}"
      end
      nc[:_grid] = [ GridFS.put(content, {filename: "#{args[0]}"}) ]
      nc[:_grid_size] = content.bytesize
      
      trace :info, "Storing #{args[0]}-#{args[1]} (#{content.bytesize} bytes) into the DB"
      nc.save
    end

    if options[:get]
      args = options[:get].split(',')

      core = ::Core.where({platform: args[0], name: args[1]}).first
      unless core.nil?
        file = GridFS.get core[:_grid].first
        File.open("#{core.platform}-#{core.name}-#{core.version}", 'wb') {|f| f.write file.read}
        trace :info, "Exporting #{core.platform}-#{core.name} #{core.version} (#{file.file_length} bytes)"
      else
        trace :info, "Core file not found in the DB"
      end
    end

    return 0
  end

  # executed from rcs-db-config
  def self.run!(*argv)
    # reopen the class and declare any empty trace method
    # if called from command line, we don't have the trace facility
    self.class_eval do
      def self.trace(level, message)
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
      # Set a banner, displayed at the top of the help screen.
      opts.banner = "Usage: rcs-db-core [options]"

      # Define the options, and what they do
      opts.on( '-l', '--list', 'get the list of cores' ) do
        options[:list] = true
      end

      opts.on( '-p', '--put FILE', 'PUT the file in the db' ) do |file|
        options[:put] = file
      end
      opts.on( '-g', '--get FILE', 'GET the file from the db' ) do |file|
        options[:get] = file
      end

      # This displays the help screen
      opts.on( '-h', '--help', 'Display this screen' ) do
        puts opts
        return 0
      end
    end

    optparse.parse(argv)

    # execute the configurator
    return Core.run(options)
  end

end #Config

end #DB::
end #RCS::