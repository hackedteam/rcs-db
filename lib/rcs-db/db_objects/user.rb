require 'mongoid'

module RCS
module DB

class User
  include Mongoid::Document
  field :name, type: String
  field :pass, type: String
  field :desc, type: String
  field :contact, type: String
  field :privs, type: Array
  field :enabled, type: Boolean
  field :locale, type: String
  field :timezone, type: Integer
  field :dashboard_items, type: Array
  attr_protected :pass
  validates_uniqueness_of :name, :message => "USER_ALREADY_EXISTS"
  store_in :users
end

end # ::DB
end # ::RCS