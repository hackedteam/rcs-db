# relatives
require_relative 'instance_processor'

# from RCS::Common
require 'rcs-common/trace'

# from System
require 'singleton'
require 'thread'

module RCS
module Worker

class QueueManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @instances = {}
    @semaphore = Mutex.new
  end
  
  def queue(instance, ident, evidence)
    return nil if instance.nil? or ident.nil? or evidence.nil?

    @semaphore.synchronize do
      idx = "#{ident}:#{instance}"

      begin
        if @instances[idx].nil?
          @instances[idx] = InstanceProcessor.new instance, ident
        end
        @instances[idx].queue(evidence)
      rescue Exception => e
        trace :error, e.message
        return nil
      end
    end
  end

  def to_s
    str = ""
    @instances.each_pair do |idx, processor|
      str += "#{processor.to_s}"
    end
    str
  end
end

end # ::Worker
end # ::RCS
