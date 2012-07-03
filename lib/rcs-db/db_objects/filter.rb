require 'mongoid'

#module RCS
#module DB

class EvidenceFilter
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user, type: Array, default: []
  field :name, type: String
  field :filter, type: String   # json

  store_in :filters
end


#end # ::DB
#end # ::RCS