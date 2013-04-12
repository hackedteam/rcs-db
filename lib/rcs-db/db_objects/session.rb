require 'mongoid'

#module RCS
#module DB

class Session
  include Mongoid::Document

  field :server, type: String
  field :level, type: Array
  field :cookie, type: String
  field :address, type: String
  field :time, type: Integer
  field :version, type: String

  # required for retrocompatiblity by the console
  field :user, type: String

  belongs_to :user, :dependent => :nullify, :autosave => true

  store_in collection: 'sessions'
end


#end # ::DB
#end # ::RCS