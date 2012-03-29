require_relative '../tasks'

module RCS
module DB

class CompactTask
  include RCS::DB::NoFileTaskType
  include RCS::Tracer

  def total
    raise "ciao conrad"
  end
  
  def next_entry
    yield @description = "Compacting DB"

    
    @description = "DB compacted successfully"
  end
end

end # DB
end # RCS