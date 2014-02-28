require 'mongoid'

#module RCS
#module DB

class Signature
  include Mongoid::Document

  field :scope, type: String
  field :value, type: String

  validates_uniqueness_of :scope

  index scope: 1

  store_in collection: 'signatures'
end


#end # ::DB
#end # ::RCS