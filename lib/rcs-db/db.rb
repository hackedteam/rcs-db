#
#  The main file of the db
#

# relatives
require_relative 'events.rb'
require_relative 'config.rb'
require_relative 'license.rb'

# from RCS::Common
require 'rcs-common/trace'

require 'mongoid'
require 'rcs-db/db_objects/user'

module RCS
module DB

class Application
  include RCS::Tracer

  # the main of the collector
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
    
    # connect to MongoDB
    begin
      Mongoid.load!(Dir.pwd + '/config/mongoid.yaml')
      Mongoid.configure do |config|
        config.master = Mongo::Connection.new.db('rcs')
      end
    rescue Exception => e
      trace :fatal, e
      exit
    end


    #FIXME: remove this...
    result = User.create(name: 'admin') do |doc|
      doc[:pass] = Digest::SHA1.hexdigest('.:RCS:.admin')
      doc[:contact] = ''
      doc[:privs] = ['ADMIN', 'TECH', 'VIEW']
      doc[:enabled] = true
      doc[:locale] = 'en_US'
      doc[:timezone] = 0
    end

    begin
      version = File.read(Dir.pwd + '/config/version.txt')
      trace :info, "Starting the RCS Database #{version}..."

      # load the license limits
      return 1 unless LicenseManager.instance.load_license

      # config file parsing
      return 1 unless Config.instance.load_from_file

      # enter the main loop (hopefully will never exit from it)
      Events.new.setup Config.instance.global['LISTENING_PORT']

    rescue Exception => e
      trace :fatal, "FAILURE: " << e.message
      trace :fatal, "EXCEPTION: [#{e.class}] " << e.backtrace.join("\n")
      return 1
    end

    return 0
  end

  # we instantiate here an object and run it
  def self.run!(*argv)
    return Application.new.run(argv)
  end

end # Application::
end #DB::
end #RCS::
