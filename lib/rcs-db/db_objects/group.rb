require 'mongoid'

#module RCS
#module DB

class Group
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :alert, type: Boolean
  
  validates_uniqueness_of :name, :message => "GROUP_ALREADY_EXISTS"

  has_and_belongs_to_many :users, :dependent => :nullify, :autosave => true#, :class_name => "RCS::DB::User", :foreign_key => "rcs/db/user_ids"
  has_and_belongs_to_many :items, :dependent => :nullify, :autosave => true

  store_in :groups

  def remove_user(user)
    user.groups.delete(self)
    self.users.delete(user)
    user.save
    self.save
  end
end

#end # ::DB
#end # ::RCS
