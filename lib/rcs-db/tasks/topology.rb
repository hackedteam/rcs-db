require_relative '../tasks'

module RCS
module DB

class TopologyTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    ::Status.where({type: 'anonymizer', status: ::Status::OK}).count + 2
  end
  
  def next_entry
    yield description "Pushing topology"

    # mark all the anonymizers as "not configured"
    ::Collector.where({type: 'remote'}).each do |anon|
      anon.configured = false
      anon.save
    end

    ::Status.where({type: 'anonymizer', status: ::Status::OK}).each do |anon|

      yield description "Configuring '#{anon.name}'"

      Frontend.rnc_push(anon.address)
    end
    
    description "Topology applied successfully"
  end
end

end # DB
end # RCS