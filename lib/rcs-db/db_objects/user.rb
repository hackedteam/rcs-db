require 'mongoid'
require 'bcrypt'

#module RCS
#module DB

class User
  include RCS::Tracer
  include Mongoid::Document
  include Mongoid::Timestamps

  PRIVS = ['ADMIN',
            'ADMIN_USERS',
            'ADMIN_OPERATIONS',
            'ADMIN_TARGETS',
            'ADMIN_AUDIT',
            'ADMIN_LICENSE',
            'ADMIN_PROFILES',
           'SYS',
            'SYS_FRONTEND',
            'SYS_BACKEND',
            'SYS_BACKUP',
            'SYS_INJECTORS',
            'SYS_CONNECTORS',
           'TECH',
            'TECH_FACTORIES',
            'TECH_BUILD',
            'TECH_CONFIG',
            'TECH_EXEC',
            'TECH_UPLOAD',
            'TECH_IMPORT',
            'TECH_NI_RULES',
           'VIEW',
            'VIEW_ALERTS',
            'VIEW_FILESYSTEM',
            'VIEW_EDIT',
            'VIEW_DELETE',
            'VIEW_EXPORT',
            'VIEW_PROFILES'
          ]

  field :name, type: String
  field :pass, type: String
  field :desc, type: String
  field :contact, type: String
  field :privs, type: Array
  field :enabled, type: Boolean
  field :locale, type: String
  field :timezone, type: Integer
  field :dashboard_ids, type: Array, default: []
  field :recent_ids, type: Array, default: []
  
  validates_uniqueness_of :name, :message => "USER_ALREADY_EXISTS"
  
  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true#, :class_name => "RCS::DB::Group", :foreign_key => "rcs/db/group_ids"
  has_many :alerts
  
  index :name
  index :enabled
  
  store_in :users

  before_destroy :destroy_callback

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

  def destroy_callback
    ::Session.destroy_all(conditions: {user: [ self._id ]})
  end

end

#end # ::DB
#end # ::RCS
