require 'mongoid'

#module RCS
#module DB

class Audit
  include Mongoid::Document
  
  field :time, type: DateTime
  field :actor, type: String
  field :action, type: String
  field :user, type: String
  field :group, type: String
  field :activity, type: String
  field :target, type: String
  field :backdoor, type: String
  field :info, type: String
  
  store_in :audit
end

class AuditSearch
  include Mongoid::Document
  
  field :actors, type: Array
  field :actions, type: Array
  field :users, type: Array
  field :groups, type: Array
  field :activities, type: Array
  field :targets, type: Array
  field :backdoors, type: Array
  
  store_in :audit_search
end

#end # ::DB
#end # ::RCS