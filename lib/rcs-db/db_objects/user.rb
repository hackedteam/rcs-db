require 'mongoid'
require 'bcrypt'

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
  field :pwd_changed_at, type: DateTime
  field :pwd_changed_cs, type: String

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true
  has_many :alerts, :dependent => :destroy
  has_one :session, :dependent => :destroy, :autosave => true

  index({name: 1}, {background: true, unique: true})
  index({enabled: 1}, {background: true})

  store_in collection: 'users'

  before_destroy :destroy_sessions

  # Runs only if dashboard_ids has been updated
  after_save { rebuild_watched_items if changed_attributes['dashboard_ids'] }

  scope :enabled, where(enabled: true)

  scope :online, lambda {
    online_user_id = Session.only(:user_id).map(&:user_id)
    enabled.in(_id: online_user_id)
  }

  # Password must be 10 characters long and contains at least 1 number, 1 uppercase letter and 1 downcase letter
  STRONG_PWD_REGEXP = /(?=.*[a-z]+)(?=.*[A-Z]+)(?=.*[0-9]+)(?=.{10,})/

  validates_uniqueness_of :name, if: :name_changed?, message: "USER_ALREADY_EXISTS"

  validates_format_of :pass, with: STRONG_PWD_REGEXP, if: :password_changed?, message: "WEAK_PASSWORD"

  # Password must not contains the username
  validate do
    errors.add(:pass, "WEAK_PASSWORD") if password_changed? and password_match_username?
  end

  before_save do
    if password_changed?
      self.pass = hash_password(self.pass)
      reset_pwd_changed_at
    end
  end

  def calculate_pwd_changed_cs
    Digest::MD5.hexdigest("#{self.id}_#{self.pwd_changed_at.to_i}")
  end

  def reset_pwd_changed_at(datetime = now)
    self.pwd_changed_at = datetime
    self.pwd_changed_cs = calculate_pwd_changed_cs
  end

  def password_match_username?
    return false unless self.pass
    return false unless self.name

    self.pass.downcase =~ /#{self.name}/i
  end

  def rebuild_watched_items
    WatchedItem.rebuild
  end

  def hash_password(password)
    BCrypt::Password.create(password).to_s
  end

  def password_expired?
    # Someone tried to change pwd_changed_at via mongodb
    return true if pwd_changed_cs != calculate_pwd_changed_cs

    password_days_left.zero?
  end

  def password_expiring?
    password_days_left <= 15
  end

  def password_days_left
    return Float::INFINITY if password_never_expire?

    three_months = 31 * 3
    elapsed_days = ((now - pwd_changed_at) / (3600 * 24)).round
    remaining_days = three_months - elapsed_days
    remaining_days < 0 ? 0 : remaining_days
  end

  def password_never_expire?
    if pwd_changed_at.nil? and pwd_changed_cs.nil? # user not migrated
      true
    else
      !!RCS::DB::Config.instance.global['PASSWORDS_NEVER_EXPIRE']
    end
  end

  def now
    Time.now.utc
  end

  def password_changed?
    return true if new_record?
    changed_attributes.keys.include?('pass')
  end

  def name_changed?
    return true if new_record?
    changed_attributes.keys.include?('name')
  end

  def has_password?(password)
    begin
      # load the hash from the db, convert to Password object and check if it matches
      if BCrypt::Password.new(self[:pass]) == password
        return true
      end
    rescue BCrypt::Errors::InvalidHash
      # retro-compatibility for the migrated account which used only the SHA1
      if self[:pass] == Digest::SHA1.hexdigest(password)
        trace :info, "Old password schema is used by #{self.name}, migrating to the new one..."
        self.pass = password
        self.save
        return true
      end
    rescue Exception => e
      trace :warn, "Error verifying password: #{e.message}"
      return false
    end

    return false
  end

  def add_recent(item)
    self.recent_ids.insert(0, {'section' => item[:section], 'type' => item[:type], 'id' => item[:id]})
    self.recent_ids.uniq!
    self.recent_ids = self.recent_ids[0..4]
    self.save
  rescue Exception => ex
    msg = "cannot add #{item[:type]} #{item[:id]} to recent list of user #{self.id}: #{ex.message}" rescue ex.message
    trace :error, "#add_recent, #{msg}"
  end

  def delete_item(id)
    if self.dashboard_ids.include? id
      trace :debug, "Deleting Item #{id} from #{self.name} dashboard"
      self.dashboard_ids.delete(id)
      self.save
    end

    self.recent_ids.each do |recent|
      # next unless recent['id'] == id or recent[:id] == id
      if recent == id or (recent.respond_to?(:[]) and (recent['id'] == id or recent[:id] == id))
        trace :debug, "Deleting Item #{id} from #{self.name} recents"
        self.recent_ids.delete(recent)
        self.save
      end
    end
  end

  def destroy_sessions
    ::Session.destroy_all(user: [self._id])
  end
end
