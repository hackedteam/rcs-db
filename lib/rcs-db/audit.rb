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
    # expected parameters:
    #  :actor
    #  :action
    #  :user_name
    #  :group_name
    #  :operation_name
    #  :target_name
    #  :agent_name
    #  :desc
    
    def log(params)
      begin
        params[:time] = Time.now.getutc.to_i
        audit = ::Audit.new params
        audit.save
        save_audit_search params
      rescue Exception => e
        trace :error, "Cannot write audit log: #{e.message}"
      end
    end

    def update_search(field, value)
      temp = Set.new field
      return temp.add(value).to_a
    end
    
    def save_audit_search(params)
      s = AuditFilters.first
      s = AuditFilters.new if s.nil?
      
      s.actor = update_search s.actor, params[:actor] if params.has_key? :actor
      s.action = update_search s.action, params[:action] if params.has_key? :action
      s.user_name = update_search s.user_name, params[:user_name] if params.has_key? :user_name
      s.group_name = update_search s.group_name, params[:group_name] if params.has_key? :group_name
      s.operation_name = update_search s.operation_name, params[:operation_name] if params.has_key? :operation_name
      s.target_name = update_search s.target_name, params[:target_name] if params.has_key? :target_name
      s.agent_name = update_search s.agent_name, params[:agent_name] if params.has_key? :agent_name
      s.save
    end
  end
end

end #DB::
end #RCS::
