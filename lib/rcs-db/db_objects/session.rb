require 'mongoid'

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

  index user: 1
  index cookie: 1
end
