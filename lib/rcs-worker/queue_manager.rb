# relatives
require_relative 'instance_processor'

# from RCS::Common
require 'rcs-common/trace'

# from System
require 'singleton'

module RCS
module Worker

class QueueManager
  include Singleton
  include RCS::Tracer
  
  def initialize
    @instances = {}
  end
  
  def queue(instance, evidence)
    return null if instance.nil? or evidence.nil?
    
    @instances[instance] ||= InstanceProcessor.new instance
    @instances[instance].queue(evidence)
  end
  
  def to_s
    str = ""
    @instances.each_pair do |instance, processor|
      str += "#{processor.to_s}"
    end
    str
  end
end

end # ::Worker
end # ::RCS
