#
# The Audit class, everything happening on the system should be logged
#

require 'rcs-common/trace'
require 'rcs-db/db_objects/audit'

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
    #  :activity
    #  :target
    #  :backdoor
    #  :desc
    def log(params)
      trace :debug, params
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
      s = AuditSearch.first
      s = AuditSearch.new if s.nil?

      s.actors = update_search s.actors, params[:actor]
      s.actions = update_search s.actions, params[:action]
      s.users = update_search s.users, params[:user]
      s.groups = update_search s.groups, params[:group]
      s.activities = update_search s.activities, params[:activity]
      s.targets = update_search s.targets, params[:target]
      s.backdoors = update_search s.backdoors, params[:backdoor]
      s.save
    end
  end
end

end #DB::
end #RCS::
