#
#  The main file of the translator
#
require 'rcs-common/path_utils'

require_release 'rcs-db/config'
require_release 'rcs-db/db_layer'
require_release 'rcs-db/grid'
require_release 'rcs-db/alert'
require_release 'rcs-db/sessions'
require_release 'rcs-db/license_component'

# from RCS::Common
require 'rcs-common/trace'

require_relative 'processor'

module RCS
module Translate

class Application
  include RCS::Tracer
  extend RCS::Tracer

  def self.trace_setup
    # if we can't find the trace config file, default to the system one
    if File.exist? 'trace.yaml'
      typ = Dir.pwd
      ty = 'trace.yaml'
    else
      typ = File.dirname(File.dirname(File.dirname(__FILE__)))
      ty = typ + "/config/trace.yaml"
      #puts "Cannot find 'trace.yaml' using the default one (#{ty})"
    end

    # ensure the log directory is present
    Dir::mkdir(Dir.pwd + '/log') if not File.directory?(Dir.pwd + '/log')
    Dir::mkdir(Dir.pwd + '/log/err') if not File.directory?(Dir.pwd + '/log/err')

    # initialize the tracing facility
    begin
      trace_init typ, ty
    rescue Exception => e
      puts e
      exit
    end
  end

  # the main of the collector
  def run(options)

    # initialize random number generator
    srand(Time.now.to_i)

    begin
      build = File.read(Dir.pwd + '/config/VERSION_BUILD')
      $version = File.read(Dir.pwd + '/config/VERSION')
      trace :fatal, "Starting the TRANSLATE Processor #{$version} (#{build})..."

      # config file parsing
      return 1 unless RCS::DB::Config.instance.load_from_file

      # connect to MongoDB
      until RCS::DB::DB.instance.connect
        trace :warn, "Cannot connect to MongoDB, retrying..."
        sleep 5
      end

      # load the license from the db (saved by db)
      LicenseManager.instance.load_from_db

      unless LicenseManager.instance.check :translation
        RCS::DB::DB.instance.mongo_connection.drop_collection 'trans_queue'

        # do nothing...
        trace :info, "TRANSLATE license is disabled, going to sleep..."
        while true do
          sleep 60
        end
      end

      # the infinite processing loop
      Processor.run

      # never reached...

    rescue Interrupt
      trace :info, "User asked to exit. Bye bye!"
      return 0
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.message
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      return 1
    end
    
    return 0
  end

  # we instantiate here an object and run it
  def self.run!(*argv)
    self.trace_setup
    return Application.new.run(argv)
  end

end # Application::
end #DB::
end #RCS::
