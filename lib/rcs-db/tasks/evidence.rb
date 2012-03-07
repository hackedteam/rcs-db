require_relative '../tasks'

module RCS
module DB

class EvidenceTask
  include RCS::DB::SingleFileTaskType
  include RCS::Tracer

  def total
    return 1
  end
  
  def next_entry
    @description = "Exporting evidence"

    yield @description = "Ended"
  end
end

end # DB
end # RCS