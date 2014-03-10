require 'mongoid'

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

    def is_duplicate?(agent, target)
      return false unless self.respond_to? :duplicate_criteria
      return false if agent.nil? or target.nil?

      db = RCS::DB::DB.instance.session
      criteria = self.duplicate_criteria
      criteria.merge! "aid" => agent['_id'].to_s
      is_duplicated = !!db["evidence.#{target['_id'].to_s}"].find.first

      if is_duplicated
        trace(:debug, "DUPLICATE CHECK #{criteria}: #{is_duplicated.inspect}")
      end

      is_duplicated
    end

    def default_keyword_index
      self[:kw] = [] unless self[:kw].kind_of?(Array)

      self[:data].each_value do |value|
        next unless value.is_a? String or value.is_a? Symbol
        self[:kw] += value.to_s.keywords
      end
      self[:kw].uniq!
    end

    def store(agent, target)
      agent = get_agent
      return nil if agent.nil?

      coll = ::Evidence.target(target[:_id].to_s)
      evidence = coll.create do |ev|

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

        # keyword full search
        ev.kw = self[:kw]

        ev.with(safe: true).save!
        ev
      end
      evidence
    end
  end

end # SingleEvidence
