#
# The Audit class, everything happening on the system should be logged
#

require 'rcs-common/trace'
require_relative 'db_objects/audit'

module RCS
module DB

class Audit
  extend RCS::Tracer
  
  class << self

    def names_from_path(path)
      hash = {}

      return hash if !path or path.empty?

      Item.collection.find(_id: {'$in' => path}).select(name: 1).each do |doc|
        if doc['_id'] == path[0]
          hash[:operation_name] = doc['name']
        elsif doc['_id'] == path[1]
          hash[:target_name] = doc['name']
        end
      end

      hash
    end

    # Expected parameters:
    #   :actor
    #   :action
    #   :user_name
    #   :group_name
    #   :operation_name
    #   :target_name
    #   :agent_name
    #   :entity_name
    #   :desc
    #   :_item
    #   :_entity
    def log(params)
      params[:time] = Time.now.getutc.to_i

      if params[:_item]
        item = params.delete(:_item)
        params[:"#{item._kind}_name"] = item.name
        params.merge!(names_from_path(item.path)) if item._kind != 'operation'
      end

      if params[:_entity]
        entity = params.delete(:_entity)
        params[:entity_name] = entity.name
        params.merge!(names_from_path(entity.path))
      end

      ::Audit.new(params).save

      update_audit_filters(params)
    rescue Exception => e
      trace(:error, "Cannot write audit log: [#{e.class}] #{e.message} #{e.backtrace}")
    end

    def update_audit_filters(params)
      audit_filters = AuditFilters.first || AuditFilters.new

      AuditFilters::FILTER_NAMES.each do |name|
        next unless params[name]
        set = Set.new(audit_filters[name])
        audit_filters[name] = set.add(params[name]).to_a
      end

      audit_filters.save
    end
  end
end

end #DB::
end #RCS::
