require 'mongoid'

#module RCS
#module DB

class Core
  include Mongoid::Document
  include Mongoid::Timestamps

  field :platform, type: String
  field :name, type: String
  field :version, type: Integer

  store_in :cores
end


#end # ::DB
#end # ::RCS