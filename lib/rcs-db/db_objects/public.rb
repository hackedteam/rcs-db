require 'mongoid'

#module RCS
#module DB

class PublicDocument
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :user, type: String
  field :factory, type: Array
  field :time, type: Integer

  index({name: 1}, {background: true})
  index({user: 1}, {background: true})

  store_in collection: 'publics'
end


#end # ::DB
#end # ::RCS