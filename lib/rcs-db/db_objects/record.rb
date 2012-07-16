require 'mongoid'

#module RCS
#module DB

class Record
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String


  field :path, type: Array

  index :name
  index :target

  store_in :records
end


#end # ::DB
#end # ::RCS