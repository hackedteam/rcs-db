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
  field :operation, type: String
  field :target, type: String
  field :backdoor, type: String
  field :desc, type: String
  
  index :time
  index :actor
  index :action
  index :user
  index :group
  index :operation
  index :target
  index :backdoor
  
  store_in :audit
  
  def to_flat_array
    column_names = Audit.fields.keys
    column_names.delete('_type') if fields.has_key? '_type'
    
    flat_array = []
    column_names.each do |name|
      flat_array << (self.attributes[name].nil? ? "" : self.attributes[name].to_s)
    end
    
    return flat_array
  end
end

class AuditFilters
  include Mongoid::Document
    
  field :actor, type: Array
  field :action, type: Array
  field :user, type: Array
  field :group, type: Array
  field :operation, type: Array
  field :target, type: Array
  field :backdoor, type: Array
  
  store_in :audit_filters
end

#end # ::DB
#end # ::RCS