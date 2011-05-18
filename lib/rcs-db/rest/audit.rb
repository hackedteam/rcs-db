#
# Controller for Audit
#

require 'json'

module RCS
module DB

class AuditController < RESTController

  def index
    require_auth_level :admin
    
    trace :debug, params
    
    # base query
    query = ::Audit
    
    # filtering
    filter = ''
    filter = JSON.parse(params['filter'].first) if params.has_key? 'filter'
    query = query.where(filter) unless filter.empty?
    
    # paging
    if params.has_key? 'startIndex' and params.has_key? 'numItems'
      start_index = params['startIndex'].first.to_i
      num_items = params['numItems'].first.to_i
      query = query.skip(start_index).limit(num_items)
    else
      # without paging, return everything
      query = query.all
    end
    
    return STATUS_OK, *json_reply(query)
  end
  
  def count
    require_auth_level :admin
    
    # base query
    query = ::Audit
    
    # filtering
    filter = ''
    filter = JSON.parse(params['filter'].first) if params.has_key? 'filter'
    trace :debug, filter.inspect
    unless filter.empty?
      num_audits = query.count(conditions: filter)
      trace :debug, "number of filtered '#{filter}' audits: #{num_audits}"
    else
      # without filtering, return grand total
      num_audits = query.count
      trace :debug, "number of total audits: #{num_audits}"
    end
    
    # FIXME: Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
    num_audits = -1 if num_audits == 0
    return STATUS_OK, *json_reply(num_audits)
  end

end

end #DB::
end #RCS::