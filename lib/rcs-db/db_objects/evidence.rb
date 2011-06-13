require 'mongoid'

#module RCS
#module DB

class Evidence
  include Mongoid::Document

  field :acquired, type: Integer
  field :received, type: Integer
  field :type, type: String
  field :relevance, type: Integer
  field :blotter, type: Boolean
  field :item, type: Array         # backdoor BSON_ID
  field :data, type: Hash

  #store_in "evidence.#{this.target}"
end


#end # ::DB
#end # ::RCS