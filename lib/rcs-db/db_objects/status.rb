require 'mongoid'

#module RCS
#module DB

class Status
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :status, type: String
  field :address, type: String
  field :info, type: String
  field :time, type: Integer
  field :pcpu, type: Integer
  field :cpu, type: Integer
  field :disk, type: Integer
  
  store_in :statuses
end

#end # ::DB
#end # ::RCS
