class AuditTask
  attr_accessor :file_name

  def initialize(params)
    @file_name = "#{@params['file_name']}.tar.gz"
  end

  def count

  end

  def next_entry
    
  end

  def create
    audits = ::Audit.filter(@params['filter'])
    audits ||= ::Audit.all

    tmpfile = Temporary.file('temp', @params['file_name'])
    begin
      trace :debug, "storing temporary audit export in #{tmpfile.path}"
      # write headers
      tmpfile.write ::Audit.field_names.to_csv
      audits.each do |p|
        tmpfile.write p.to_flat_array.to_csv
      end
    ensure
      tmpfile.close
    end
    
    return @file_name,
  end
end
