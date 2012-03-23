require 'mongoid'

#module RCS
#module DB

class Audit
  include Mongoid::Document
  
  field :time, type: Integer
  field :actor, type: String
  field :action, type: String
  field :user_name, type: String
  field :group_name, type: String
  field :operation_name, type: String
  field :target_name, type: String
  field :agent_name, type: String
  field :desc, type: String
  
  index :time
  index :actor
  index :action
  index :user_name
  index :group_name
  index :operation_name
  index :target_name
  index :agent_name
  
  store_in :audit

  def self.filter(params)

    filter, filter_hash = ::Audit.common_filter params

    # copy remaining filtering criteria (if any)
    filtering = ::Audit
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    query = filtering.where(filter_hash).order_by([[:time, :asc]])

    return query
  end

  def self.filtered_count(params)

    filter, filter_hash = ::Audit.common_filter params

    # copy remaining filtering criteria (if any)
    filtering = ::Audit
    filter.each_key do |k|
      filtering = filtering.any_in(k.to_sym => filter[k])
    end

    num_audits = filtering.where(filter_hash).count

    return num_audits
  end


  def self.common_filter(params)

    # filtering
    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter' and params['filter'].is_a? String
    # must duplicate here since we delete the param later but we need to keep the parameter intact for
    # subsequent calls
    filter = params['filter'].dup if params.has_key? 'filter' and params['filter'].is_a? Hash

    # if not specified the filter on the date is last 24 hours
    filter['from'] = Time.now.to_i - 86400 if filter['from'].nil?
    filter['to'] = Time.now.to_i if filter['to'].nil?

    # to remove a filter set it to 0
    filter.delete('from') if filter['from'] == 0
    filter.delete('to') if filter['to'] == 0

    filter_hash = {}

    # date filters must be treated separately
    filter_hash[:time.gte] = filter.delete('from') if filter.has_key? 'from'
    filter_hash[:time.lte] = filter.delete('to') if filter.has_key? 'to'

    # desc filters must be handled as a regexp
    if filter.has_key? 'desc'
      filter_hash[:desc] = Regexp.new(filter.delete('desc'), true)
    end

    return filter, filter_hash
  end

  def self.mongo_filter(params)

    filter = {}
    filter = JSON.parse(params['filter']) if params.has_key? 'filter' and params['filter'].is_a? String
    filter = params['filter'] if params.has_key? 'filter' and params['filter'].is_a? Hash

    # default date filtering is last 24 hours
    filter["from"] = Time.now.to_i - 86400 if filter['from'].nil?
    filter["to"] = Time.now.to_i if filter['to'].nil?

    filter_hash = {}

    filter_hash["time"] = Hash.new
    filter_hash["time"]["$gte"] = filter.delete('from') if filter.has_key? 'from'
    filter_hash["time"]["$lte"] = filter.delete('to') if filter.has_key? 'to'

    filter_hash["desc"] = Regexp.new(filter.delete('desc'), true) if filter.has_key? 'desc'

    # remaining filters
    filter.each_key do |k|
      filter_hash[k] = {"$in" => filter[k]}
    end

    puts "FILTER: #{filter} FILTER_HASH: #{filter_hash}"

    return filter, filter_hash
  end

  def self.field_names
    column_names = Audit.fields.keys
    column_names.delete('_type') if fields.has_key? '_type'
    column_names.delete('_id') if fields.has_key? '_id'
    return column_names
  end

  def to_flat_array
    column_names = Audit.field_names
    
    flat_array = []
    column_names.each do |name|
      value = (self.attributes[name].nil? ? "" : self.attributes[name].to_s)
      
      case name
        when 'time'
          value = Time.at(value.to_i).getutc.to_s
      end
      
      flat_array << value
    end
    
    return flat_array
  end
end

class AuditFilters
  include Mongoid::Document
    
  field :actor, type: Array
  field :action, type: Array
  field :user_name, type: Array
  field :group_name, type: Array
  field :operation_name, type: Array
  field :target_name, type: Array
  field :agent_name, type: Array
  
  store_in :audit_filters
end

#end # ::DB
#end # ::RCS