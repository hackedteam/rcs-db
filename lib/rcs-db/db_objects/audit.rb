require 'mongoid'

#module RCS
#module DB

class Audit
  include Mongoid::Document
  
  field :time, type: Integer
  field :actor, type: String
  field :action, type: String
  field :user, type: String
  field :group, type: String
  field :activity, type: String
  field :target, type: String
  field :backdoor, type: String
  field :info, type: String
  
  index :time

  store_in :audit
end

class AuditFilters
  include Mongoid::Document
    
  field :actor, type: Array
  field :action, type: Array
  field :user, type: Array
  field :group, type: Array
  field :activity, type: Array
  field :target, type: Array
  field :backdoor, type: Array
  
  store_in :audit_filters
end

#end # ::DB
#end # ::RCS