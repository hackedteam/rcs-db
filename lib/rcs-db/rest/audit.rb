#
# Controller for Audit
#

module RCS
module DB

class AuditController < RESTController

  def index
    require_auth_level :admin
    
    trace :debug, params
    
    query = ::Audit
    filterString = params['filterParam1'].first if params.has_key? 'filterParam1'
    query.where(action: filterString)
    start_index = params['startIndex'].first.to_i
    num_items = params['numItems'].first.to_i
    
    return STATUS_OK, *json_reply(query.skip(start_index).limit(num_items))
  end
  
  def count
    require_auth_level :admin
    
    query = ::Audit
    if params.has_key? 'filterParam1'
      filterString = params['filterParam1'].first
      num_audits = query.count(conditions: {action: filterString})
    else
      num_audits = query.count
    end
    trace :debug, "number of current audits: #{num_audits}, params #{params}"
    return STATUS_OK, *json_reply(num_audits)
  end

end

end #DB::
end #RCS::