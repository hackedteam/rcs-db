require_relative 'generator'

class AuditTask
  extend TaskGenerator
  
  store_in :file, 'temp'
  single_file "auditlog.csv"
  
  def initialize(params)
    @filter = params['filter']
  end
  
  def total
    return (::Audit.count + 1) if @filter.nil?
    (::Audit.filtered_count(@filter) + 1)
  end
  
  def next_entry
    @description = "exporting audit logs"

    audits = ::Audit.filter(@filter) unless @filter.nil?
    audits ||= ::Audit.all

    # header
    yield ::Audit.field_names.to_csv

    #rows
    audits.each do |p|
      yield p.to_flat_array.to_csv
    end
  end
end
