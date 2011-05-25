require 'mongoid'

#module RCS
#module DB

class Collector
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :desc, type: String
  field :type, type: String
  field :address, typs: String
  field :port, type: Integer
  field :instance, type: String
  field :poll, type: Boolean
  field :version, type: String
  field :configured, type: Boolean

  field :next, type: Array
  field :prev, type: Array

  store_in :collectors
end


#end # ::DB
#end # ::RCS