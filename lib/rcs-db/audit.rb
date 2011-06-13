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
    #  :user
    #  :group
    #  :operation
    #  :target
    #  :backdoor
    #  :desc
    
    def log(params)
      params[:time] = Time.now.getutc.to_i
      audit = ::Audit.new params
      audit.save
      save_audit_search params
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
      s.user = update_search s.user, params[:user] if params.has_key? :user
      s.group = update_search s.group, params[:group] if params.has_key? :group
      s.operation = update_search s.activity, params[:operation] if params.has_key? :operation
      s.target = update_search s.target, params[:target] if params.has_key? :target
      s.backdoor = update_search s.backdoor, params[:backdoor] if params.has_key? :backdoor
      s.save
    end
  end
end

end #DB::
end #RCS::
