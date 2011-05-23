require 'mongoid'

#module RCS
#module DB

class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  field :pass, type: String
  field :desc, type: String
  field :contact, type: String
  field :privs, type: Array
  field :enabled, type: Boolean
  field :locale, type: String
  field :timezone, type: Integer
  field :dashboard_items, type: Array
  
  validates_uniqueness_of :name, :message => "USER_ALREADY_EXISTS"
  
  references_and_referenced_in_many :groups, :dependent => :nullify, :autosave => true#, :class_name => "RCS::DB::Group", :foreign_key => "rcs/db/group_ids"
  
  store_in :users

  def remove_from_group(group)
    group.users.delete(self)
    self.groups.delete(group)
    group.save
    self.save
  end

  def verify_password(password)
    # we use the SHA1 with a salt '.:RCS:.' to avoid rainbow tabling
    if self[:pass] == Digest::SHA1.hexdigest('.:RCS:.' + password)
      return true
    end

    # retro-compatibility for the migrated account which used only the SHA1
    if self[:pass] == Digest::SHA1.hexdigest(password)
      return true
    end

    return false
  end
end

#end # ::DB
#end # ::RCS
