require 'mongoid'
require 'bcrypt'

#module RCS
#module DB

class User
  include RCS::Tracer
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
  field :dashboard_ids, type: Array
  field :recent_ids, type: Array, default: []
  
  validates_uniqueness_of :name, :message => "USER_ALREADY_EXISTS"
  
  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true#, :class_name => "RCS::DB::Group", :foreign_key => "rcs/db/group_ids"
  has_many :alerts
  
  index :name
  index :enabled
  
  store_in :users

  def create_password(password)
    self[:pass] = BCrypt::Password.create(password).to_s
  end

  def verify_password(password)
    begin
      # load the hash from the db, convert to Password object and check if it matches
      if BCrypt::Password.new(self[:pass]) == password
        return true
      end
    rescue BCrypt::Errors::InvalidHash
      # retro-compatibility for the migrated account which used only the SHA1
      if self[:pass] == Digest::SHA1.hexdigest(password)
        trace :info, "Old password schema is used by #{self.name}, migrating to the new one..."
        # convert to the new format so the next time it will be migrated
        self.create_password(password)
        self.save
        return true
      end
    rescue Exception => e
      trace :warn, "Error verifying password: #{e.message}"
      return false
    end

    return false
  end

  def delete_item(id)
    if self.dashboard_ids.include? id
      trace :debug, "Deleting Item #{id} from #{self.name} dashboard"
      self.dashboard_ids.delete(id)
      self.save
    end

    if self.recent_ids.include? id
      trace :debug, "Deleting Item #{id} from #{self.name} recents"
      self.recent_ids.delete(id)
      self.save
    end
  end

end

#end # ::DB
#end # ::RCS
