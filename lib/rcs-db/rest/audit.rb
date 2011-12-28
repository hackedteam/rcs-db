#
# Controller for Audit
#

require 'csv'
require 'json'
require 'tempfile'

require 'rcs-common/temporary'

module RCS
module DB

class AuditController < RESTController

  def index
    require_auth_level :admin
    
    # filtering
    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'
    
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

    mongoid_query do
      # copy remaining filtering criteria (if any)
      filtering = ::Audit
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      # paging
      if @params.has_key? 'startIndex' and @params.has_key? 'numItems'
        start_index = @params['startIndex'].to_i
        num_items = @params['numItems'].to_i
        #trace :debug, "Querying with filter #{filter_hash}."
        query = filtering.where(filter_hash).order_by([[:time, :asc]]).skip(start_index).limit(num_items)
      else
        # without paging, return everything
        query = filtering.where(filter_hash).order_by([[:time, :asc]])
      end

      ok(query)
    end
  end
  
  def count
    require_auth_level :admin
    
    # filtering
    filter = {}
    filter = JSON.parse(@params['filter']) if @params.has_key? 'filter'

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

    mongoid_query do
      # copy remaining filtering criteria (if any)
      filtering = ::Audit
      filter.each_key do |k|
        filtering = filtering.any_in(k.to_sym => filter[k])
      end

      num_audits = filtering.where(filter_hash).count

      #trace :debug, "number of filtered audits: " + num_audits.to_s unless num_audits.nil?

      # Flex RPC does not accept 0 (zero) as return value for a pagination (-1 is a safe alternative)
      num_audits = -1 if num_audits == 0
      ok(num_audits)
    end
  end
  
  def filters
    require_auth_level :admin
    
    search = ::AuditFilters.first
    return ok(search)
  end
  
end

end #DB::
end #RCS::