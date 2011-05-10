require 'mongoid'

module RCS
module DB

class Group
  include Mongoid::Document
  field :name, type: String

  validates_uniqueness_of :name, :message => "GROUP_ALREADY_EXISTS"

  has_and_belongs_to_many :users, :dependent => :nullify, :class_name => "RCS::DB::User", :foreign_key => "user_ids"

  #store_in :groups
end

end # ::DB
end # ::RCS
