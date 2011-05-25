require 'mongoid'

#module RCS
#module DB

class Configuration
  include Mongoid::Document
  include Mongoid::Timestamps

  field :desc, type: String
  field :user, type: String
  field :saved, type: Integer
  field :sent, type: Integer
  field :activated, type: Integer

  field :config, type: String
  
  embedded_in :item
end


class Template
  include Mongoid::Document
  include Mongoid::Timestamps

  field :desc, type: String
  field :user, type: String

  field :config, type: String

  store_in :templates
end


#end # ::DB
#end # ::RCS