require 'mongoid'

#module RCS
#module DB

class PublicDocument
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :user, type: Array
  field :factory, type: Array
  field :time, type: Integer

  index :name
  index :user

  store_in :publics
end


#end # ::DB
#end # ::RCS