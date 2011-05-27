#
# Controller for Audit
#

require 'json'

module RCS
module DB

class AuditController < RESTController

  def index
    require_auth_level :admin
    
    # filtering
    filter = {}
    filter = JSON.parse(params['filter'].first) if params.has_key? 'filter'
    
    filter_hash = {}
    
    # date filters must be treated separately
    if filter.has_key? 'from' and filter.has_key? 'to'
      filter_hash[:time.gte] = filter.delete('from')
      filter_hash[:time.lte] = filter.delete('to')
      #trace :debug, "Filtering date from #{filter['from']} to #{filter['to']}."
    end
    
    # desc filters must be handled as a regexp
    if filter.has_key? 'desc'
      #trace :debug, "Filtering description by keywork '#{filter['desc']}'."
      filter_hash[:desc] = Regexp.new(filter.delete('desc'), true)
    end
    
    # copy remaining filtering criteria (if any)
    filter_hash.merge!(filter)

    # paging
    if params.has_key? 'startIndex' and params.has_key? 'numItems'
      start_index = params['startIndex'].first.to_i
      num_items = params['numItems'].first.to_i
      #trace :debug, "Querying with filter #{filter_hash}."
      query = ::Audit.where(filter_hash).order_by([[:time, :asc]]).skip(start_index).limit(num_items)
    else
      # without paging, return everything
      query = ::Audit.where(filter_hash).order_by([[:time, :asc]])
    end
    
    return STATUS_OK, *json_reply(query)
  end
  
  def count
    require_auth_level :admin
    
    # filtering
    filter = {}
    filter = JSON.parse(params['filter'].first) if params.has_key? 'filter'

    filter_hash = {}

    # date filters must be treated separately
    if filter.has_key? 'from' and filter.has_key? 'to'
      filter_hash[:time.gte] = filter.delete('from')
      filter_hash[:time.lte] = filter.delete('to')
      #trace :debug, "Filtering date from #{filter['from']} to #{filter['to']}."
    end

    # desc filters must be handled as a regexp
    if filter.has_key? 'desc'
      #trace :debug, "Filtering description by keywork '#{filter['desc']}'."
      filter_hash[:desc] = Regexp.new(filter.delete('desc'), true)
    end
    
    # copy remaining filtering criteria (if any)
    filter_hash.merge!(filter)

    unless filter_hash.empty?
      num_audits = ::Audit.count(conditions: filter_hash)
      #trace :debug, "number of filtered '#{filter}' audits: #{num_audits}"
    else
      # without filtering, return grand total
      num_audits = ::Audit.count
      #trace :debug, "number of total audits: #{num_audits}"
    end
    
    # FIXME: Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
    num_audits = -1 if num_audits == 0
    return STATUS_OK, *json_reply(num_audits)
  end
  
  def filters
    require_auth_level :admin
    
    search = ::AuditFilters.first
    return STATUS_OK, *json_reply(search)
  end
  
end

end #DB::
end #RCS::