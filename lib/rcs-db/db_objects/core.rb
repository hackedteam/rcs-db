require 'mongoid'

#module RCS
#module DB

class Core
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :version, type: Integer
  field :_grid, type: Array
  field :_grid_size, type: Integer

  index :name
  
  store_in :cores
end


#end # ::DB
#end # ::RCS