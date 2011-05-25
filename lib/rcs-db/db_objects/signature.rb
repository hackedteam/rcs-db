require 'mongoid'

#module RCS
#module DB

class Signature
  include Mongoid::Document

  field :name, type: String
  field :value, type: String

  validates_uniqueness_of :name

  store_in :signatures
end


#end # ::DB
#end # ::RCS