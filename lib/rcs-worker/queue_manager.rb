# from RCS::Common
require 'rcs-common/trace'

# from System
require 'singleton'

module RCS
module Worker

class QueueManager
  include Singleton
  include RCS::Tracer
  
  # To change this template use File | Settings | File Templates.
  def initialize
    # this hash has instances as keys, and array of evidences ids as values
    @evidences = {}
  end
  
  def queue(instance, evidence)
    return null if instance.nil? or evidence.nil?

    @evidences[instance] ||= []
    @evidences[instance] << evidence
    trace :info, "queued #{evidence} for instance #{instance}."
  end
  
  def to_s
    str = ""
    @evidences.each_pair do |instance, evidences|
      str += "instance #{@id}: #{@evidences}\n"
    end
    str
  end
end

end # ::Worker
end # ::RCS
