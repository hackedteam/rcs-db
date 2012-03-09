require_relative '../tasks'

module RCS
module DB

class AuditTask
  include RCS::DB::SingleFileTaskType

  def internal_filename
    'audit.csv'
  end

  def total
    return (::Audit.count + 1) if @params['filter'].nil?
    (::Audit.filtered_count(@params['filter']) + 1)
  end
  
  def next_entry
    @description = "Exporting audit logs"
    
    audits = ::Audit.filter(@params['filter']) unless @params['filter'].nil?
    audits ||= ::Audit.all
    
    # header
    yield ::Audit.field_names.to_csv
    
    #rows
    audits.each do |p|
      yield p.to_flat_array.to_csv
    end
  end
end

end # DB
end # RCS