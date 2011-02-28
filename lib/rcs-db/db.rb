#
# The main file of the DB
#

# from RCS::Common
require 'rcs-common/trace'

module RCS
module DB

  class Application
    include RCS::Tracer

    # To change this template use File | Settings | File Templates.
    def run(options)

      # if we can't find the trace config file, default to the system one
      if File.exist? 'trace.yaml' then
        typ = Dir.pwd
        ty = 'trace.yaml'
      else
        typ = File.dirname(File.dirname(File.dirname(__FILE__)))
        ty = typ + "/config/trace.yaml"
        #puts "Cannot find 'trace.yaml' using the default one (#{ty})"
      end

      # ensure the log directory is present
      Dir::mkdir(Dir.pwd + '/log') if not File.directory?(Dir.pwd + '/log')

      # initialize the tracing facility
      begin
        trace_init typ, ty
      rescue Exception => e
        puts e
        exit
      end

      begin
        version = File.read(Dir.pwd + '/config/version.txt')
        trace :info, "Starting the RCS Database #{version}..."
      end
      
      return 0
    end

    # we instantiate here an object and run it
    def self.run!(*argv)
      return Application.new.run(argv)
    end
  end


end # DB::
end # RCS::