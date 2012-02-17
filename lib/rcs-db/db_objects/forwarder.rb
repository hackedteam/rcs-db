require 'mongoid'

#module RCS
#module DB

class Forwarder
  include Mongoid::Document
  include Mongoid::Timestamps

  field :enabled, type: Boolean
  field :name, type: String
  field :type, type: String, default: "JSON"
  field :dest, type: String
  field :raw, type: Boolean
  field :keep, type: Boolean, default: true
  field :path, type: Array

  store_in :forwarders
end

#end # ::DB
#end # ::RCS