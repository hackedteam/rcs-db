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
      ::Item.agents.where({instance: self[:instance], ident: self[:ident]}).first
    end
    
    def store(agent, target)
      evidence = ::Evidence.collection_class(target[:_id].to_s)
      evidence.create do |ev|

        ev.aid = agent[:_id].to_s
        ev.type = self[:type]

        ev.da = self[:da].to_i
        ev.dr = self[:dr].to_i
        ev.rel = 0
        ev.blo = false
        ev.note = ""

        ev.data = self[:data]

        # save the binary data (if any)
        unless self[:grid_content].nil?
          ev.data[:_grid_size] = self[:grid_content].bytesize
          ev.data[:_grid] = RCS::DB::GridFS.put(self[:grid_content], {filename: agent[:_id].to_s}, target[:_id].to_s) unless self[:grid_content].nil?
        end

        ev.save
      end

      return evidence
    end
  end

end # SingleEvidence
